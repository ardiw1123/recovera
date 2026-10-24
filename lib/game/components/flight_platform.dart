import '../../features/sky_balance/game_models.dart';

class FlightPlatform {
  const FlightPlatform({
    required this.startX,
    required this.endX,
    required this.topY,
    this.thickness = 16,
    this.kind = PlatformKind.bridge,
  });

  final double startX;
  final double endX;
  final double topY;
  final double thickness;
  final PlatformKind kind;

  double get centerX => (startX + endX) / 2;
  double get width => endX - startX;
}

enum PlatformKind { start, bridge, narrow, checkpoint, finish, bouncePad }

class WorldPoint {
  const WorldPoint(this.x, this.y);

  final double x;
  final double y;
}

class FlightWorldLayout {
  FlightWorldLayout._();

  static const double worldWidth = 390;
  static const double startY = 520;
  static const double finishHeight = 4200;
  static const double finishY = startY - finishHeight;
  static const double platformSpacing = 105;
  static const int platformCount = 41;

  static const List<double> _centers = [
    195,
    270,
    125,
    235,
    90,
    300,
    165,
    275,
    115,
    225,
  ];

  static final List<FlightPlatform> platforms = List.unmodifiable(
    List<FlightPlatform>.generate(platformCount, (index) {
      final centerX = index == 0
          ? worldWidth / 2
          : _centers[index % _centers.length];
      final width = index == 0
          ? 170.0
          : index == platformCount - 1
          ? 126.0
          : index % 10 == 0
          ? 126.0
          : (112 - index * .65 - (index % 4 == 0 ? 18 : 0))
                .clamp(86, 112)
                .toDouble();
      final kind = index == 0
          ? PlatformKind.start
          : index == platformCount - 1
          ? PlatformKind.finish
          : index % 10 == 0
          ? PlatformKind.checkpoint
          : index % 4 == 0
          ? PlatformKind.narrow
          : PlatformKind.bridge;
      final topY = startY - index * platformSpacing;
      return FlightPlatform(
        startX: centerX - width / 2,
        endX: centerX + width / 2,
        topY: topY,
        kind: kind,
      );
    }),
  );

  static FlightPlatform platformNearY(double y) {
    return platforms.reduce(
      (current, next) =>
          (y - current.topY).abs() < (y - next.topY).abs() ? current : next,
    );
  }

  static WorldPoint foodPosition(FoodItem food) {
    final y = startY - food.progress * finishHeight - 18 - food.y * 12;
    return WorldPoint(
      (worldWidth / 2 + food.x * 145).clamp(22, worldWidth - 22).toDouble(),
      y,
    );
  }

  static WorldPoint obstaclePosition(SkyObstacle obstacle, double x) {
    final y = startY - obstacle.progress * finishHeight - obstacle.y * 12;
    return WorldPoint(
      (worldWidth / 2 + x * 145).clamp(22, worldWidth - 22).toDouble(),
      y,
    );
  }

  static WorldPoint checkpointPosition(SkyCheckpoint checkpoint) {
    final y = startY - checkpoint.progress * finishHeight;
    final platform = platformNearY(y);
    return WorldPoint(platform.centerX, platform.topY - 1);
  }
}
