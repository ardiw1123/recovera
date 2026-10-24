import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/game/components/flight_platform.dart';
import 'package:recovera/game/systems/physics_engine.dart';

void main() {
  const engine = PhysicsEngine();
  const platform = FlightPlatform(startX: 0, endX: 300, topY: 300);

  test('horizontal tilt accelerates the jumper smoothly across the screen', () {
    final body = PhysicsBody(x: 150, y: 200);

    engine.step(
      body: body,
      deltaSeconds: .1,
      horizontalTilt: .6,
      platforms: const [platform],
    );

    expect(body.velocityX, greaterThan(0));
    expect(body.x, greaterThan(150));
    expect(body.velocityY, greaterThan(0));
  });

  test('landing on a platform automatically launches the next jump', () {
    final body = PhysicsBody(x: 150, y: 210, velocityY: 180);

    for (var index = 0; index < 10; index++) {
      engine.step(
        body: body,
        deltaSeconds: .05,
        horizontalTilt: 0,
        platforms: const [platform],
      );
    }

    expect(body.landingCount, 1);
    expect(body.y, lessThan(platform.topY - body.radius));
    expect(body.velocityY, lessThan(0));
  });

  test('horizontal movement wraps around both screen edges', () {
    final body = PhysicsBody(x: 386, y: 100, velocityX: 250);

    engine.step(
      body: body,
      deltaSeconds: .05,
      horizontalTilt: 0,
      platforms: const [],
    );

    expect(body.x, lessThan(30));
  });

  test('vertical course has progressively higher reachable platforms', () {
    final platforms = FlightWorldLayout.platforms;

    expect(platforms.length, FlightWorldLayout.platformCount);
    expect(platforms.first.topY, FlightWorldLayout.startY);
    expect(platforms.last.topY, FlightWorldLayout.finishY);
    for (var index = 1; index < platforms.length; index++) {
      expect(
        platforms[index - 1].topY - platforms[index].topY,
        FlightWorldLayout.platformSpacing,
      );
    }
  });
}
