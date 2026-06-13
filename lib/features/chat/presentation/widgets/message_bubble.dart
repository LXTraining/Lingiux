import 'package:flutter/material.dart';
import '../../domain/entities/chat_entity.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/formatters.dart';

class MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final Function(String, Offset, Size) onWordTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.onWordTap,
  });

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      colors: [Color(0xFF815BF5), Color(0xFF5A45FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isMe ? null : AppColors.surface,
              border: isMe ? null : Border.all(color: AppColors.border, width: 1),
              boxShadow: isMe
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
            ),
            child: Wrap(
              children: _buildWordWidgets(message.text, isMe),
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

  List<Widget> _buildWordWidgets(String text, bool isMe) {
    final words = text.split(' ');
    return words.asMap().entries.map((entry) {
      final isLast = entry.key == words.length - 1;
      return _TappableWord(
        word: entry.value,
        displayText: isLast ? entry.value : '${entry.value} ',
        textStyle: TextStyle(
          color: isMe ? Colors.white : AppColors.onSurface,
          fontSize: 15,
          height: 1.45,
        ),
        onTap: onWordTap,
      );
    }).toList();
  }
}

class _TappableWord extends StatefulWidget {
  final String word;
  final String displayText;
  final TextStyle textStyle;
  final Function(String, Offset, Size) onTap;

  const _TappableWord({
    required this.word,
    required this.displayText,
    required this.textStyle,
    required this.onTap,
  });

  @override
  State<_TappableWord> createState() => _TappableWordState();
}

class _TappableWordState extends State<_TappableWord> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        final RenderBox box = context.findRenderObject() as RenderBox;
        final Offset globalPosition = box.localToGlobal(Offset.zero);
        final Offset centerPosition = Offset(
          globalPosition.dx + box.size.width / 2,
          globalPosition.dy,
        );
        widget.onTap(widget.word, centerPosition, box.size);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primary.withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(widget.displayText, style: widget.textStyle),
      ),
    );
  }
}
