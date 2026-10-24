import '../components/flight_platform.dart';

class BalanceConfig {
  static const double tiltAcceleration = 700;
  static const double airResistance = 0.97;
  static const double maxHorizontalSpeed = 250;
  static const double gravity = 950;
  static const double jumpImpulse = -590;
  static const double deadZone = 0.06;
}

class PhysicsBody {
  PhysicsBody({
    required this.x,
    required this.y,
    this.velocityX = 0,
    this.velocityY = 0,
    this.radius = 14,
  });

  double x;
  double y;
  double velocityX;
  double velocityY;
  final double radius;
  bool grounded = false;
  bool isJumping = false;
  double jumpScale = 1;
  double shadowOffset = 0;
  int landingCount = 0;

  void reset({
    required double x,
    required double y,
    double velocityX = 0,
    double velocityY = 0,
  }) {
    this.x = x;
    this.y = y;
    this.velocityX = velocityX;
    this.velocityY = velocityY;
    grounded = false;
    isJumping = false;
    jumpScale = 1;
    shadowOffset = 0;
    landingCount = 0;
  }
}

class PhysicsEngine {
  const PhysicsEngine();

  void step({
    required PhysicsBody body,
    required double deltaSeconds,
    required double horizontalTilt,
    required List<FlightPlatform> platforms,
    double worldWidth = FlightWorldLayout.worldWidth,
  }) {
    if (deltaSeconds <= 0) return;
    final safeDelta = deltaSeconds.clamp(0.0, .08).toDouble();
    final steps = (safeDelta / (1 / 120)).ceil().clamp(1, 10);
    final stepDelta = safeDelta / steps;
    final tilt = horizontalTilt.clamp(-1.0, 1.0).toDouble();

    for (var index = 0; index < steps; index++) {
      _stepOnce(body, stepDelta, tilt, platforms, worldWidth);
    }
  }

  void _stepOnce(
    PhysicsBody body,
    double deltaSeconds,
    double tilt,
    List<FlightPlatform> platforms,
    double worldWidth,
  ) {
    final previousBottom = body.y + body.radius;
    body.velocityX += tilt * BalanceConfig.tiltAcceleration * deltaSeconds;
    body.velocityX *= BalanceConfig.airResistance;
    body.velocityX = body.velocityX
        .clamp(
          -BalanceConfig.maxHorizontalSpeed,
          BalanceConfig.maxHorizontalSpeed,
        )
        .toDouble();
    body.velocityY += BalanceConfig.gravity * deltaSeconds;

    body.x += body.velocityX * deltaSeconds;
    body.y += body.velocityY * deltaSeconds;
    if (body.x < 0) {
      body.x += worldWidth;
    } else if (body.x >= worldWidth) {
      body.x -= worldWidth;
    }

    body.grounded = false;
    if (body.velocityY < 0) return;

    for (final platform in platforms) {
      if (body.x + body.radius < platform.startX ||
          body.x - body.radius > platform.endX) {
        continue;
      }
      final crossedTop =
          previousBottom <= platform.topY &&
          body.y + body.radius >= platform.topY;
      if (!crossedTop) continue;

      body.y = platform.topY - body.radius;
      body.velocityY = BalanceConfig.jumpImpulse;
      body.grounded = true;
      body.isJumping = true;
      body.landingCount++;
      return;
    }
  }
}
