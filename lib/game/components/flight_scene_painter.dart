import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/sky_balance/game_models.dart';
import '../systems/physics_engine.dart';
import 'flight_platform.dart';

class FlightScenePainter extends CustomPainter {
  const FlightScenePainter({
    required this.level,
    required this.body,
    required this.cameraY,
    required this.progress,
    required this.elapsedSeconds,
    required this.collectedFoods,
    required this.collectingFoods,
    required this.passedCheckpoints,
    this.drawPlayerSprite = true,
  });

  final SkyBalanceLevel level;
  final PhysicsBody body;
  final double cameraY;
  final double progress;
  final double elapsedSeconds;
  final Set<int> collectedFoods;
  final Map<int, DateTime> collectingFoods;
  final Set<int> passedCheckpoints;

  /// When false only the player's shadow is painted, because the avatar is
  /// drawn as a widget on top of the scene.
  final bool drawPlayerSprite;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / FlightWorldLayout.worldWidth;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFBDEBFA), Color(0xFFE9F8FC), Color(0xFFDDF2E8)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);
    _drawClouds(canvas, size, scale);
    _drawHeightMarks(canvas, size, scale);

    for (final platform in FlightWorldLayout.platforms) {
      final y = _screenY(platform.topY, scale);
      if (y < -40 * scale || y > size.height + 40 * scale) continue;
      _drawPlatform(canvas, platform, y, scale);
    }

    for (var index = 0; index < level.checkpoints.length; index++) {
      if (passedCheckpoints.contains(index)) continue;
      final checkpoint = level.checkpoints[index];
      final point = FlightWorldLayout.checkpointPosition(checkpoint);
      final y = _screenY(point.y, scale);
      if (y < -70 * scale || y > size.height + 30 * scale) continue;
      _drawCheckpoint(canvas, point.x * scale, y, scale, checkpoint.label);
    }

    for (var index = 0; index < level.food.length; index++) {
      final collectedAt = collectingFoods[index];
      if (collectedFoods.contains(index) && collectedAt == null) continue;
      final food = level.food[index];
      final point = FlightWorldLayout.foodPosition(food);
      final screenPoint = Offset(point.x * scale, _screenY(point.y, scale));
      if (!_visible(screenPoint, size, 40 * scale)) continue;
      final collectedProgress = collectedAt == null
          ? 0.0
          : (DateTime.now().difference(collectedAt).inMilliseconds / 360)
                .clamp(0.0, 1.0)
                .toDouble();
      _drawFood(
        canvas,
        screenPoint,
        scale,
        food.emoji,
        index,
        collectedProgress,
      );
    }

    for (var index = 0; index < level.obstacles.length; index++) {
      final obstacle = level.obstacles[index];
      final x = obstacle.kind == ObstacleKind.moving
          ? obstacle.x + math.sin(elapsedSeconds * 1.8 + index) * .22
          : obstacle.x;
      final point = FlightWorldLayout.obstaclePosition(obstacle, x);
      final screenPoint = Offset(point.x * scale, _screenY(point.y, scale));
      if (!_visible(screenPoint, size, 70 * scale)) continue;
      _drawObstacle(canvas, screenPoint, scale, obstacle);
    }

    final finishY = _screenY(FlightWorldLayout.finishY, scale);
    if (finishY > -100 * scale && finishY < size.height + 100 * scale) {
      _drawFinish(canvas, finishY, size, scale);
    }

    final player = Offset(body.x * scale, _screenY(body.y, scale));
    _drawPlayer(canvas, player, scale);
  }

  double _screenY(double worldY, double scale) => (worldY - cameraY) * scale;

  bool _visible(Offset point, Size size, double margin) =>
      point.dx > -margin &&
      point.dx < size.width + margin &&
      point.dy > -margin &&
      point.dy < size.height + margin;

  void _drawClouds(Canvas canvas, Size size, double scale) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .65);
    for (var index = 0; index < 9; index++) {
      final x =
          ((index * 137 + (index.isEven ? 0 : 85)) %
                  (FlightWorldLayout.worldWidth * scale))
              .toDouble();
      final worldY =
          FlightWorldLayout.startY -
          ((index * 193 + 90) % FlightWorldLayout.finishHeight);
      final y = _screenY(worldY, scale);
      if (y < -50 * scale || y > size.height + 50 * scale) continue;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 72 * scale,
          height: 24 * scale,
        ),
        paint,
      );
      canvas.drawCircle(
        Offset(x - 13 * scale, y - 7 * scale),
        15 * scale,
        paint,
      );
      canvas.drawCircle(
        Offset(x + 11 * scale, y - 8 * scale),
        19 * scale,
        paint,
      );
    }
  }

  void _drawHeightMarks(Canvas canvas, Size size, double scale) {
    final step = 500.0;
    final first = math.max(
      0,
      ((FlightWorldLayout.startY - cameraY) / step).floor() - 1,
    );
    for (
      var index = first;
      index <= first + (size.height / (step * scale)).ceil() + 2;
      index++
    ) {
      final worldY = FlightWorldLayout.startY - index * step;
      final y = _screenY(worldY, scale);
      if (y < 0 || y > size.height) continue;
      final paint = Paint()
        ..color = const Color(0xFF72B5C8).withValues(alpha: .24)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(size.width, y),
        paint,
      );
      _drawText(
        canvas,
        '${index * 500}',
        Offset(8 * scale, y - 16 * scale),
        9 * scale,
      );
    }
  }

  void _drawPlatform(
    Canvas canvas,
    FlightPlatform platform,
    double y,
    double scale,
  ) {
    final rect = Rect.fromLTWH(
      platform.startX * scale,
      y,
      platform.width * scale,
      platform.thickness * scale,
    );
    final color = switch (platform.kind) {
      PlatformKind.start => const Color(0xFF45B88A),
      PlatformKind.checkpoint => const Color(0xFF46B8C8),
      PlatformKind.finish => const Color(0xFFF0AE4E),
      PlatformKind.narrow => const Color(0xFF73C88C),
      _ => const Color(0xFF57BD8C),
    };
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(Offset(0, 5 * scale)),
        Radius.circular(8 * scale),
      ),
      Paint()..color = const Color(0xFF315363).withValues(alpha: .2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(8 * scale)),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(3 * scale),
        Radius.circular(6 * scale),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale
        ..color = Colors.white.withValues(alpha: .7),
    );
  }

  void _drawFood(
    Canvas canvas,
    Offset point,
    double scale,
    String emoji,
    int index,
    double collectProgress,
  ) {
    final bob = math.sin(elapsedSeconds * 2 + index) * 3 * scale;
    final center = point.translate(0, bob);
    canvas.drawCircle(
      center.translate(0, 2 * scale),
      17 * scale,
      Paint()..color = const Color(0xFF328454).withValues(alpha: .16),
    );
    canvas.drawCircle(
      center,
      17 * scale,
      Paint()..color = const Color(0xFFE8FFF0),
    );
    _drawText(
      canvas,
      emoji,
      center.translate(0, -12 * scale),
      23 * scale * (1 + collectProgress * .5),
      opacity: 1 - collectProgress,
    );
  }

  void _drawObstacle(
    Canvas canvas,
    Offset point,
    double scale,
    SkyObstacle obstacle,
  ) {
    if (obstacle.kind == ObstacleKind.storm ||
        obstacle.kind == ObstacleKind.wind) {
      final cloud = Paint()
        ..color = const Color(0xFF8BA4BA).withValues(alpha: .8);
      canvas.drawOval(
        Rect.fromCenter(center: point, width: 56 * scale, height: 26 * scale),
        cloud,
      );
      canvas.drawCircle(
        point.translate(-12 * scale, -5 * scale),
        12 * scale,
        cloud,
      );
      canvas.drawCircle(
        point.translate(7 * scale, -8 * scale),
        16 * scale,
        cloud,
      );
      if (obstacle.kind == ObstacleKind.storm) {
        _drawText(canvas, '⚡', point.translate(0, 3 * scale), 18 * scale);
      }
      return;
    }
    final radius = obstacle.kind == ObstacleKind.gate ? 21 * scale : 17 * scale;
    canvas.drawCircle(point, radius, Paint()..color = const Color(0xFF77878D));
    _drawText(
      canvas,
      obstacle.emoji,
      point.translate(0, -13 * scale),
      22 * scale,
    );
  }

  void _drawCheckpoint(
    Canvas canvas,
    double x,
    double y,
    double scale,
    String label,
  ) {
    canvas.drawCircle(
      Offset(x, y),
      23 * scale,
      Paint()..color = const Color(0xFF1B9B8D).withValues(alpha: .16),
    );
    _drawText(canvas, '★', Offset(x, y - 9 * scale), 24 * scale);
    _drawText(canvas, label, Offset(x, y - 37 * scale), 9 * scale);
  }

  void _drawFinish(Canvas canvas, double y, Size size, double scale) {
    final centerX = size.width / 2;
    final paint = Paint()
      ..color = const Color(0xFF178A79)
      ..strokeWidth = 4 * scale;
    canvas.drawLine(
      Offset(centerX - 46 * scale, y),
      Offset(centerX - 46 * scale, y + 82 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + 46 * scale, y),
      Offset(centerX + 46 * scale, y + 82 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - 46 * scale, y),
      Offset(centerX + 46 * scale, y),
      paint,
    );
    _drawText(
      canvas,
      'SKY SUMMIT',
      Offset(centerX, y - 26 * scale),
      14 * scale,
    );
  }

  void _drawPlayer(Canvas canvas, Offset point, double scale) {
    final shadowRadius = 12 * scale * (1 + body.shadowOffset * .4);
    canvas.drawOval(
      Rect.fromCenter(
        center: point.translate(0, (19 + body.shadowOffset * 23) * scale),
        width: shadowRadius * 2,
        height: shadowRadius * .55,
      ),
      Paint()
        ..color = const Color(0xFF286A87)
            .withValues(alpha: .24 * (1 - body.shadowOffset * .5)),
    );
    if (!drawPlayerSprite) return;
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate((body.velocityX * .001).clamp(-.3, .3));
    canvas.scale(body.jumpScale);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: 31 * scale,
        height: 35 * scale,
      ),
      Paint()..color = const Color(0xFF62C58A),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 4 * scale),
        width: 24 * scale,
        height: 26 * scale,
      ),
      Paint()..color = const Color(0xFF92E3A9),
    );
    canvas.drawCircle(
      Offset(-4 * scale, -3 * scale),
      2 * scale,
      Paint()..color = const Color(0xFF204D5C),
    );
    canvas.drawCircle(
      Offset(4 * scale, -3 * scale),
      2 * scale,
      Paint()..color = const Color(0xFF204D5C),
    );
    canvas.drawLine(
      Offset(-7 * scale, 15 * scale),
      Offset(-11 * scale, 20 * scale),
      Paint()
        ..color = const Color(0xFF347C69)
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(7 * scale, 15 * scale),
      Offset(11 * scale, 20 * scale),
      Paint()
        ..color = const Color(0xFF347C69)
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    double fontSize, {
    double opacity = 1,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF244B5B).withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(canvas, position.translate(-painter.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant FlightScenePainter oldDelegate) => true;
}
