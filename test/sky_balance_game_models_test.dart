import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/features/sky_balance/game_models.dart';

void main() {
  group('Sky Balance level', () {
    test('has food-only collectibles and all required course elements', () {
      final level = SkyBalanceLevel.firstJump;

      expect(level.food, hasLength(20));
      expect(level.food.every((food) => food.name.isNotEmpty), isTrue);
      expect(level.food.every((food) => food.emoji.isNotEmpty), isTrue);
      expect(
        level.obstacles.map((item) => item.kind).toSet(),
        containsAll(ObstacleKind.values),
      );
      expect(level.checkpoints, hasLength(3));
    });

    test('food energy is capped at 100 and never falls below zero', () {
      expect(recoverEnergy(95, 15), 100);
      expect(recoverEnergy(40, 10), 50);
      expect(recoverEnergy(0, 0), 0);
    });
  });

  group('Sky Balance result', () {
    test('rewards reaching the finish without requiring every food', () {
      final result = SkyBalanceResult.fromRun(
        won: true,
        score: 1250,
        foodCollected: 12,
        energyRemaining: 43,
        obstaclesHit: 3,
        checkpointsReached: 3,
        progress: 1,
      );

      expect(result.won, isTrue);
      expect(result.stars, 2);
      expect(result.recoveryPoints, 50);
      expect(result.foodCollected, 12);
    });

    test('clamps result score, energy, and progress to valid values', () {
      final result = SkyBalanceResult.fromRun(
        won: false,
        score: -50,
        foodCollected: 0,
        energyRemaining: -3,
        obstaclesHit: 4,
        checkpointsReached: 1,
        progress: 1.2,
      );

      expect(result.score, 0);
      expect(result.energyRemaining, 0);
      expect(result.progress, 1);
      expect(result.recoveryPoints, 0);
    });
  });
}
