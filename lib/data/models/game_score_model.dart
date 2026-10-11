import '../database/database_constants.dart';

/// Data model representing a game score record in SQLite table `game_scores`.
/// Used for mini-game "Food Saver Challenge" per US-14 and US-12.
class GameScoreModel {
  final int? id;
  final int score;
  final int itemsSaved;
  final String? badge;
  final String playedAt;

  const GameScoreModel({
    this.id,
    required this.score,
    required this.itemsSaved,
    this.badge,
    required this.playedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      DatabaseConstants.colGameScore: score,
      DatabaseConstants.colGameItemsSaved: itemsSaved,
      DatabaseConstants.colGameBadge: badge,
      DatabaseConstants.colGamePlayedAt: playedAt,
    };
    if (id != null) {
      map[DatabaseConstants.colGameId] = id;
    }
    return map;
  }

  factory GameScoreModel.fromMap(Map<String, dynamic> map) {
    return GameScoreModel(
      id: map[DatabaseConstants.colGameId] as int?,
      score: map[DatabaseConstants.colGameScore] as int,
      itemsSaved: map[DatabaseConstants.colGameItemsSaved] as int,
      badge: map[DatabaseConstants.colGameBadge] as String?,
      playedAt: map[DatabaseConstants.colGamePlayedAt] as String,
    );
  }

  factory GameScoreModel.create({
    required int score,
    required int itemsSaved,
    String? badge,
    DateTime? playedAt,
  }) {
    return GameScoreModel(
      score: score,
      itemsSaved: itemsSaved,
      badge: badge,
      playedAt: (playedAt ?? DateTime.now()).toIso8601String(),
    );
  }

  GameScoreModel copyWith({
    int? id,
    int? score,
    int? itemsSaved,
    String? badge,
    String? playedAt,
  }) {
    return GameScoreModel(
      id: id ?? this.id,
      score: score ?? this.score,
      itemsSaved: itemsSaved ?? this.itemsSaved,
      badge: badge ?? this.badge,
      playedAt: playedAt ?? this.playedAt,
    );
  }
}
