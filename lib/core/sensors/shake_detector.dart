import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// PBI-13: Shake-to-Refresh Detector
///
/// Mendeteksi guncangan gawai berbasis sensor Accelerometer (`sensors_plus`).
/// Menghitung magnitude vektor percepatan tangan:
///   magnitude = sqrt(x² + y² + z²)
///
/// Jika magnitude >= threshold (default 25.0 m/s²) dan waktu jeda throttle
/// (default 2 detik) telah terpenuhi, maka callback [onShake] akan dipanggil.
class ShakeDetector {
  ShakeDetector({
    required this.onShake,
    this.threshold = defaultThreshold,
    this.throttleDuration = defaultThrottle,
    this.sensorStream,
  });

  /// Threshold percepatan dalam m/s² (Gravitasi normal bumi ~ 9.8 m/s²)
  static const double defaultThreshold = 25.0;

  /// Jeda throttle untuk mencegah multiple trigger berturut-turut
  static const Duration defaultThrottle = Duration(seconds: 2);

  final VoidCallback onShake;
  final double threshold;
  final Duration throttleDuration;
  final Stream<AccelerometerEvent>? sensorStream;

  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime _lastShakeTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isListening = false;

  bool get isListening => _isListening;
  DateTime get lastShakeTime => _lastShakeTime;

  /// Menghitung magnitude vektor percepatan 3 dimensi
  static double calculateMagnitude(double x, double y, double z) {
    return math.sqrt(x * x + y * y + z * z);
  }

  /// Memulai mendengarkan stream sensor accelerometer
  void startListening() {
    if (_isListening) return;
    _isListening = true;

    final stream = sensorStream ?? accelerometerEventStream();
    _subscription = stream.listen(
      _handleEvent,
      onError: (Object error) {
        debugPrint('ShakeDetector error: $error');
      },
      cancelOnError: false,
    );
  }

  /// Memproses event akselerasi
  void _handleEvent(AccelerometerEvent event) {
    final magnitude = calculateMagnitude(event.x, event.y, event.z);

    if (magnitude >= threshold) {
      final now = DateTime.now();
      if (now.difference(_lastShakeTime) >= throttleDuration) {
        _lastShakeTime = now;
        onShake();
      }
    }
  }

  /// Menghentikan langganan sensor sementara (misal saat app background)
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
  }

  /// Membersihkan seluruh resource sensor
  void dispose() {
    stopListening();
  }
}
