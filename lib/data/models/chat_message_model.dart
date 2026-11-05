import 'dart:convert';
import '../database/database_constants.dart';

class ChatMessageModel {
  final int? id;
  final int userId;
  final String role; // 'user' | 'assistant'
  final String message;
  final String? intent;
  final String? richCardJson;
  final DateTime createdAt;

  ChatMessageModel({
    this.id,
    required this.userId,
    required this.role,
    required this.message,
    this.intent,
    this.richCardJson,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  Map<String, dynamic>? get richCard {
    if (richCardJson == null || richCardJson!.isEmpty) return null;
    try {
      return jsonDecode(richCardJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) DatabaseConstants.colChatId: id,
      DatabaseConstants.colChatUserId: userId,
      DatabaseConstants.colChatRole: role,
      DatabaseConstants.colChatMessage: message,
      DatabaseConstants.colChatIntent: intent,
      DatabaseConstants.colChatRichCardJson: richCardJson,
      DatabaseConstants.colChatCreatedAt: createdAt.toIso8601String(),
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map[DatabaseConstants.colChatId] as int?,
      userId: map[DatabaseConstants.colChatUserId] as int? ?? 0,
      role: map[DatabaseConstants.colChatRole] as String? ?? 'assistant',
      message: map[DatabaseConstants.colChatMessage] as String? ?? '',
      intent: map[DatabaseConstants.colChatIntent] as String?,
      richCardJson: map[DatabaseConstants.colChatRichCardJson] as String?,
      createdAt: map[DatabaseConstants.colChatCreatedAt] != null
          ? DateTime.tryParse(map[DatabaseConstants.colChatCreatedAt] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
