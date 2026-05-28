import 'package:flutter/material.dart';
import '../../domain/entities/chat_entity.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/formatters.dart';

class MessageBubble extends StatelessWidget {
  final MessageEntity message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 10,
        left: isMe ? 56 : 0,
        right: isMe ? 0 : 56,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isMe ? null : AppColors.surfaceVariant,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.onSurface,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatMessageTime(message.time),
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
