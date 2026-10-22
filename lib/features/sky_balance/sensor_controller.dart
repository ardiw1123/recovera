import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MotionInput {
  const MotionInput({this.horizontal = 0});

  final double horizontal;
}

class SensorAvailability {
  const SensorAvailability({
    required this.accelerometer,
    required this.gyroscope,
  });

  final bool accelerometer;
  final bool gyroscope;
}

class SensorController {
  static const double deadZone = 0.12;
  static const double smoothing = 0.82;
  static const double dashThreshold = 2.4;
  static const Duration signalTimeout = Duration(seconds: 3);

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  double _neutralX = 0;
  double _filteredX = 0;
  DateTime? _lastAccelerometerEvent;
  bool _signalLost = false;
  bool _gyroscopeAvailable = false;
  DateTime _lastDashAt = DateTime.fromMillisecondsSinceEpoch(0);
  double _sensitivity = 0.8;

  MotionInput get input => MotionInput(horizontal: _filteredX);
  double get sensitivity => _sensitivity;
  set sensitivity(double value) {
    _sensitivity = value.clamp(0.5, 1.5).toDouble();
  }

  bool get signalLost =>
      _signalLost ||
      (_lastAccelerometerEvent != null &&
          DateTime.now().difference(_lastAccelerometerEvent!) > signalTimeout);
  bool get gyroscopeAvailable => _gyroscopeAvailable;

  Future<SensorAvailability> checkAvailability() async {
    final checks = await Future.wait([
      _hasSample(accelerometerEventStream()),
      _hasSample(gyroscopeEventStream()),
    ]);
    _gyroscopeAvailable = checks[1];
    return SensorAvailability(accelerometer: checks[0], gyroscope: checks[1]);
  }

  Future<bool> _hasSample<T>(Stream<T> stream) async {
    try {
      await stream.first.timeout(const Duration(milliseconds: 1400));
      return true;
    } on TimeoutException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> calibrate({
    Duration duration = const Duration(seconds: 3),
  }) async {
    var samples = 0;
    var sumX = 0.0;
    Object? sensorError;
    final subscription = accelerometerEventStream().listen(
      (event) {
        sumX += event.x;
        samples++;
      },
      onError: (Object error) {
        sensorError = error;
      },
    );
    await Future<void>.delayed(duration);
    await subscription.cancel();
    if (sensorError != null) {
      throw StateError('Accelerometer calibration failed: $sensorError');
    }
    if (samples < 6) {
      throw StateError(
        'Not enough accelerometer readings for calibration ($samples samples).',
      );
    }
    _neutralX = sumX / samples;
    _filteredX = 0;
    _signalLost = false;
    _lastAccelerometerEvent = DateTime.now();
  }

  void startListening({required void Function(int direction) onDash}) {
    stopListening();
    _signalLost = false;
    _lastAccelerometerEvent = DateTime.now();
    _accelerometerSubscription = accelerometerEventStream().listen(
      (event) {
        _lastAccelerometerEvent = DateTime.now();
        _signalLost = false;
        final horizontal = normalizeTilt(
          accelerationX: event.x,
          neutralX: _neutralX,
          sensitivity: _sensitivity,
        );
        _filteredX = _filteredX * smoothing + horizontal * (1 - smoothing);
      },
      onError: (_) {
        _signalLost = true;
      },
    );
    if (_gyroscopeAvailable) {
      _gyroscopeSubscription = gyroscopeEventStream().listen(
        (event) {
          final now = DateTime.now();
          final rate = event.y;
          if (rate.abs() >= dashThreshold &&
              now.difference(_lastDashAt) >= const Duration(seconds: 2)) {
            _lastDashAt = now;
            onDash(rate.isNegative ? -1 : 1);
          }
        },
        onError: (_) {
          _gyroscopeAvailable = false;
        },
      );
    }
  }

  static double normalizeTilt({
    required double accelerationX,
    required double neutralX,
    double sensitivity = 0.8,
  }) {
    final normalized =
        (-(accelerationX - neutralX) / (7.0 / sensitivity.clamp(0.5, 1.5)))
            .clamp(-1.0, 1.0)
            .toDouble();
    if (normalized.abs() <= deadZone) return 0;
    return (normalized.sign * ((normalized.abs() - deadZone) / (1 - deadZone)))
        .toDouble();
  }

  void stopListening() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _filteredX = 0;
  }

  void dispose() => stopListening();
}
