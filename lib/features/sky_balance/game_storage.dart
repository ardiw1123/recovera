import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/game_repository.dart';
import 'game_models.dart';

class GameStorage {
  GameStorage({GameRepository? repository})
    : _repository = repository ?? GameRepository();

  static const _bestScoreKey = 'sky_balance_best_score';
  static const _highestProgressKey = 'sky_balance_best_distance';
  static const _gamesPlayedKey = 'sky_balance_games_played';
  static const _gamesWonKey = 'sky_balance_games_won';
  static const _totalFoodKey = 'sky_balance_total_food';
  static const _recoveryPointsKey = 'sky_balance_recovery_points';

  final GameRepository _repository;

  Future<int> get bestScore async {
    final prefs = await SharedPreferences.getInstance();
    final localBest = prefs.getInt(_bestScoreKey) ?? 0;
    final previousScores = await _repository.getLeaderboard(limit: 1);
    return previousScores.isEmpty
        ? localBest
        : (previousScores.first.score > localBest
              ? previousScores.first.score
              : localBest);
  }

  Future<int> get gamesPlayed async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_gamesPlayedKey) ?? 0;
  }

  Future<bool> recordResult(SkyBalanceResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final previousBest = await bestScore;
    await _repository.recordGameScore(
      score: result.score,
      itemsSaved: result.foodCollected,
      customBadge: result.won
          ? 'Recovera Jump ${result.stars}-Star Climb'
          : null,
    );
    final isNewBest = result.score > previousBest;
    await prefs.setInt(_bestScoreKey, isNewBest ? result.score : previousBest);
    final previousProgress = prefs.getDouble(_highestProgressKey) ?? 0;
    await prefs.setDouble(
      _highestProgressKey,
      result.progress > previousProgress ? result.progress : previousProgress,
    );
    await prefs.setInt(
      _gamesPlayedKey,
      (prefs.getInt(_gamesPlayedKey) ?? 0) + 1,
    );
    if (result.won) {
      await prefs.setInt(_gamesWonKey, (prefs.getInt(_gamesWonKey) ?? 0) + 1);
      await prefs.setInt(
        _recoveryPointsKey,
        (prefs.getInt(_recoveryPointsKey) ?? 0) + result.recoveryPoints,
      );
    }
    await prefs.setInt(
      _totalFoodKey,
      (prefs.getInt(_totalFoodKey) ?? 0) + result.foodCollected,
    );
    return isNewBest;
  }
}
