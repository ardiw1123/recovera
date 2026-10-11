import '../models/game_score_model.dart';
import '../services/local_database_service.dart';

/// Repository for mini-game "Food Saver Challenge" per US-14.
/// Stores scores, items saved, and badges locally in SQLite table `game_scores` without backend API.
class GameRepository {
  final LocalDatabaseService _localDb;

  GameRepository({LocalDatabaseService? localDb})
      : _localDb = localDb ?? LocalDatabaseService();

  /// Save game score result. Automatically assigns badges based on performance.
  Future<GameScoreModel> recordGameScore({
    required int score,
    required int itemsSaved,
    String? customBadge,
  }) async {
    // Determine badge based on performance if not explicitly given
    String? badge = customBadge;
    if (badge == null) {
      if (itemsSaved >= 20 || score >= 200) {
        badge = 'Zero Waste Champion';
      } else if (itemsSaved >= 10 || score >= 100) {
        badge = 'Food Saver Hero';
      } else if (itemsSaved >= 5) {
        badge = 'Rescue Rookie';
      }
    }

    final model = GameScoreModel.create(
      score: score,
      itemsSaved: itemsSaved,
      badge: badge,
    );

    final id = await _localDb.insertScore(model);
    return model.copyWith(id: id);
  }

  /// Get top scores for local leaderboard.
  Future<List<GameScoreModel>> getLeaderboard({int limit = 10}) async {
    return await _localDb.getTopScores(limit: limit);
  }

  /// Get recent game sessions.
  Future<List<GameScoreModel>> getRecentScores({int limit = 20}) async {
    return await _localDb.getRecentScores(limit: limit);
  }

  /// Get cumulative items rescued across all local games played.
  Future<int> getTotalItemsSaved() async {
    return await _localDb.getTotalItemsSaved();
  }

  /// Reset game history.
  Future<void> clearGameHistory() async {
    await _localDb.clearScores();
  }
}
