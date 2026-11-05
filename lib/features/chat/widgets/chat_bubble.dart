import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_message_model.dart';
import 'rich_card_widget.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;

  const ChatBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final timeStr = DateFormat('HH:mm').format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : AppColors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser ? null : Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.message.replaceAll('**', '').replaceAll('*', ''),
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      height: 1.45,
                      color: isUser ? AppColors.white : AppColors.darkNavy,
                    ),
                  ),
                ),
                if (!isUser && message.richCard != null) ...[
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.78,
                    child: RichCardWidget(cardData: message.richCard!),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    timeStr,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.slateText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 6),
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.darkNavy,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 16,
                color: AppColors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
