import 'dart:math' as math;

enum SkyBalanceStage {
  menu,
  introduction,
  tutorial,
  sensorCheck,
  calibration,
  countdown,
  playing,
  paused,
  gameOver,
  victory,
  result,
}

enum ObstacleKind { rock, storm, gate, moving, wind }

int recoverEnergy(int current, int amount) =>
    (current + amount).clamp(0, 100).toInt();

class FoodItem {
  const FoodItem({
    required this.progress,
    required this.x,
    required this.y,
    required this.name,
    required this.emoji,
    required this.energy,
    required this.score,
  });

  final double progress;
  final double x;
  final double y;
  final String name;
  final String emoji;
  final int energy;
  final int score;
}

class SkyObstacle {
  const SkyObstacle({
    required this.progress,
    required this.x,
    required this.y,
    required this.kind,
    this.width = 0.2,
  });

  final double progress;
  final double x;
  final double y;
  final ObstacleKind kind;
  final double width;

  String get emoji => switch (kind) {
    ObstacleKind.rock => '🪨',
    ObstacleKind.storm => '⛈️',
    ObstacleKind.gate => '🚧',
    ObstacleKind.moving => '🪵',
    ObstacleKind.wind => '💨',
  };

  String get label => switch (kind) {
    ObstacleKind.rock => 'Floating rock',
    ObstacleKind.storm => 'Storm cloud',
    ObstacleKind.gate => 'Narrow gate',
    ObstacleKind.moving => 'Moving obstacle',
    ObstacleKind.wind => 'Wind zone',
  };

  bool get isZone => kind == ObstacleKind.storm || kind == ObstacleKind.wind;
}

class SkyCheckpoint {
  const SkyCheckpoint({required this.progress, required this.label});

  final double progress;
  final String label;
}

class SkyBalanceLevel {
  const SkyBalanceLevel({
    required this.food,
    required this.obstacles,
    required this.checkpoints,
  });

  final List<FoodItem> food;
  final List<SkyObstacle> obstacles;
  final List<SkyCheckpoint> checkpoints;

  static const firstJump = SkyBalanceLevel(
    food: [
      FoodItem(
        progress: .055,
        x: -.45,
        y: .1,
        name: 'Apple',
        emoji: '🍎',
        energy: 10,
        score: 50,
      ),
      FoodItem(
        progress: .105,
        x: .35,
        y: -.25,
        name: 'Banana',
        emoji: '🍌',
        energy: 15,
        score: 60,
      ),
      FoodItem(
        progress: .155,
        x: -.15,
        y: .55,
        name: 'Strawberry',
        emoji: '🍓',
        energy: 10,
        score: 70,
      ),
      FoodItem(
        progress: .205,
        x: .62,
        y: .2,
        name: 'Orange',
        emoji: '🍊',
        energy: 10,
        score: 55,
      ),
      FoodItem(
        progress: .255,
        x: -.62,
        y: -.35,
        name: 'Sandwich',
        emoji: '🥪',
        energy: 20,
        score: 100,
      ),
      FoodItem(
        progress: .305,
        x: .1,
        y: .65,
        name: 'Milk',
        emoji: '🥛',
        energy: 15,
        score: 80,
      ),
      FoodItem(
        progress: .355,
        x: .55,
        y: -.5,
        name: 'Avocado',
        emoji: '🥑',
        energy: 12,
        score: 65,
      ),
      FoodItem(
        progress: .405,
        x: -.42,
        y: .15,
        name: 'Carrot',
        emoji: '🥕',
        energy: 10,
        score: 50,
      ),
      FoodItem(
        progress: .455,
        x: .36,
        y: .5,
        name: 'Bread',
        emoji: '🍞',
        energy: 12,
        score: 60,
      ),
      FoodItem(
        progress: .505,
        x: -.6,
        y: -.55,
        name: 'Grapes',
        emoji: '🍇',
        energy: 10,
        score: 70,
      ),
      FoodItem(
        progress: .555,
        x: .02,
        y: -.05,
        name: 'Apple',
        emoji: '🍎',
        energy: 10,
        score: 50,
      ),
      FoodItem(
        progress: .605,
        x: .65,
        y: .5,
        name: 'Banana',
        emoji: '🍌',
        energy: 15,
        score: 60,
      ),
      FoodItem(
        progress: .655,
        x: -.48,
        y: .65,
        name: 'Strawberry',
        emoji: '🍓',
        energy: 10,
        score: 70,
      ),
      FoodItem(
        progress: .705,
        x: .36,
        y: -.6,
        name: 'Sandwich',
        emoji: '🥪',
        energy: 20,
        score: 100,
      ),
      FoodItem(
        progress: .755,
        x: -.12,
        y: .28,
        name: 'Milk',
        emoji: '🥛',
        energy: 15,
        score: 80,
      ),
      FoodItem(
        progress: .805,
        x: .6,
        y: -.1,
        name: 'Orange',
        emoji: '🍊',
        energy: 10,
        score: 55,
      ),
      FoodItem(
        progress: .855,
        x: -.6,
        y: -.2,
        name: 'Avocado',
        emoji: '🥑',
        energy: 12,
        score: 65,
      ),
      FoodItem(
        progress: .905,
        x: .18,
        y: .65,
        name: 'Carrot',
        emoji: '🥕',
        energy: 10,
        score: 50,
      ),
      FoodItem(
        progress: .945,
        x: -.35,
        y: -.6,
        name: 'Bread',
        emoji: '🍞',
        energy: 12,
        score: 60,
      ),
      FoodItem(
        progress: .975,
        x: .52,
        y: .25,
        name: 'Grapes',
        emoji: '🍇',
        energy: 10,
        score: 70,
      ),
    ],
    obstacles: [
      SkyObstacle(progress: .13, x: -.65, y: -.5, kind: ObstacleKind.rock),
      SkyObstacle(progress: .22, x: .55, y: -.45, kind: ObstacleKind.rock),
      SkyObstacle(progress: .32, x: -.5, y: .35, kind: ObstacleKind.moving),
      SkyObstacle(
        progress: .39,
        x: .2,
        y: .2,
        kind: ObstacleKind.wind,
        width: .72,
      ),
      SkyObstacle(
        progress: .47,
        x: -.58,
        y: .45,
        kind: ObstacleKind.gate,
        width: .34,
      ),
      SkyObstacle(progress: .53, x: .6, y: -.35, kind: ObstacleKind.rock),
      SkyObstacle(
        progress: .61,
        x: -.12,
        y: -.25,
        kind: ObstacleKind.storm,
        width: .52,
      ),
      SkyObstacle(progress: .68, x: .52, y: .35, kind: ObstacleKind.moving),
      SkyObstacle(
        progress: .73,
        x: -.58,
        y: -.5,
        kind: ObstacleKind.gate,
        width: .36,
      ),
      SkyObstacle(
        progress: .79,
        x: .1,
        y: .3,
        kind: ObstacleKind.wind,
        width: .75,
      ),
      SkyObstacle(progress: .84, x: -.55, y: .55, kind: ObstacleKind.rock),
      SkyObstacle(
        progress: .89,
        x: .55,
        y: -.45,
        kind: ObstacleKind.storm,
        width: .52,
      ),
      SkyObstacle(progress: .93, x: -.5, y: -.35, kind: ObstacleKind.moving),
      SkyObstacle(
        progress: .96,
        x: .3,
        y: .5,
        kind: ObstacleKind.gate,
        width: .38,
      ),
    ],
    checkpoints: [
      SkyCheckpoint(progress: .25, label: 'TRAINING'),
      SkyCheckpoint(progress: .5, label: 'BALANCE'),
      SkyCheckpoint(progress: .75, label: 'CHALLENGE'),
    ],
  );
}

class SkyBalanceResult {
  const SkyBalanceResult({
    required this.won,
    required this.score,
    required this.foodCollected,
    required this.energyRemaining,
    required this.obstaclesHit,
    required this.checkpointsReached,
    required this.progress,
    required this.stars,
    required this.recoveryPoints,
  });

  final bool won;
  final int score;
  final int foodCollected;
  final int energyRemaining;
  final int obstaclesHit;
  final int checkpointsReached;
  final double progress;
  final int stars;
  final int recoveryPoints;

  factory SkyBalanceResult.fromRun({
    required bool won,
    required int score,
    required int foodCollected,
    required int energyRemaining,
    required int obstaclesHit,
    required int checkpointsReached,
    required double progress,
  }) {
    final stars = !won
        ? 0
        : energyRemaining >= 60 && foodCollected >= 14 && obstaclesHit <= 2
        ? 3
        : energyRemaining >= 30
        ? 2
        : 1;
    return SkyBalanceResult(
      won: won,
      score: math.max(0, score),
      foodCollected: foodCollected,
      energyRemaining: energyRemaining.clamp(0, 100).toInt(),
      obstaclesHit: obstaclesHit,
      checkpointsReached: checkpointsReached,
      progress: progress.clamp(0, 1).toDouble(),
      stars: stars,
      recoveryPoints: won ? 50 : 0,
    );
  }
}
