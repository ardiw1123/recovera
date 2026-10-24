import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/features/sky_balance/sensor_controller.dart';

void main() {
  group('Sky Balance tilt input', () {
    test('calibrated neutral position produces no movement', () {
      expect(
        SensorController.normalizeTilt(accelerationX: 2.4, neutralX: 2.4),
        0,
      );
    });

    test('small hand tremors remain inside the dead zone', () {
      expect(
        SensorController.normalizeTilt(accelerationX: 3.0, neutralX: 2.4),
        0,
      );
    });

    test('tilt directions are opposite and stronger tilt moves more', () {
      final left = SensorController.normalizeTilt(
        accelerationX: 4.4,
        neutralX: 2.4,
      );
      final right = SensorController.normalizeTilt(
        accelerationX: 0.4,
        neutralX: 2.4,
      );
      final stronger = SensorController.normalizeTilt(
        accelerationX: 5.4,
        neutralX: 2.4,
      );

      expect(left, lessThan(0));
      expect(right, greaterThan(0));
      expect(stronger.abs(), greaterThan(left.abs()));
    });

    test('sensitivity changes response but clamps to a safe range', () {
      final gentle = SensorController.normalizeTilt(
        accelerationX: 4.4,
        neutralX: 2.4,
        sensitivity: 0.5,
      );
      final responsive = SensorController.normalizeTilt(
        accelerationX: 4.4,
        neutralX: 2.4,
        sensitivity: 1.5,
      );
      final overSensitive = SensorController.normalizeTilt(
        accelerationX: 10.4,
        neutralX: 2.4,
        sensitivity: 3,
      );

      expect(responsive.abs(), greaterThan(gentle.abs()));
      expect(overSensitive, -1);
    });
  });
}
