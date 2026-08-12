import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat_entity.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../vocabulary/presentation/screens/word_detail_screen.dart';
import '../../../vocabulary/domain/models/word_card_model.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../screens/chat_detail_screen.dart';

class MessageBubble extends ConsumerWidget {
  final MessageEntity message;
  final String conversationId;
  final Function(String messageId, String word, Offset globalPosition, Size wordSize) onWordTap;
  final String? senderName;
  final String? senderAvatar;

  const MessageBubble({
    super.key,
    required this.message,
    required this.conversationId,
    required this.onWordTap,
    this.senderName,
    this.senderAvatar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCard = message.text.startsWith('[CARD]:');
    if (isCard) {
      final parts = message.text.split(':');
      final word = parts.length > 1 ? parts[1] : '';
      final cardId = parts.length > 2 ? parts[2] : null;
      return _buildSharedCardBubble(context, ref, word, cardId);
    }

    final isMe = message.isMe;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 10,
        left: isMe ? 56 : 0,
        right: isMe ? 0 : 56,
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 42.0, bottom: 4.0),
              child: Text(
                senderName!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe && senderName != null) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.border,
                  backgroundImage: senderAvatar != null ? NetworkImage(senderAvatar!) : null,
                  child: senderAvatar == null
                      ? Text(
                          senderName!.substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
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
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: EdgeInsets.only(right: 4, left: (!isMe && senderName != null) ? 42.0 : 4.0),
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
        onTap: (word, offset, size) {
          onWordTap(message.id, word, offset, size);
        },
      );
    }).toList();
  }

  Widget _buildSharedCardBubble(BuildContext context, WidgetRef ref, String word, String? cardId) {
    final cardController = FlippableCardController();
    final wordCardsAsync = ref.watch(wordCardsProvider);

    WordCardModel? specificCard;
    if (wordCardsAsync.hasValue && cardId != null) {
      final list = wordCardsAsync.value!;
      for (final w in list) {
        if (w.id == cardId) {
          specificCard = w;
          break;
        }
      }
    }

    void navigateToDetail() {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              WordDetailScreen(
                selectedWord: word,
                cardId: cardId,
                conversationId: conversationId,
              ),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  ),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
    }

    final isMe = message.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          top: 8,
          bottom: 8,
          left: isMe ? 56 : 16,
          right: isMe ? 16 : 56,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && senderName != null)
              Padding(
                padding: const EdgeInsets.only(left: 42.0, bottom: 4.0),
                child: Text(
                  senderName!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe && senderName != null) ...[
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.border,
                    backgroundImage: senderAvatar != null ? NetworkImage(senderAvatar!) : null,
                    child: senderAvatar == null
                        ? Text(
                            senderName!.substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (_) {},
                        onHorizontalDragUpdate: (_) {},
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity != null &&
                              details.primaryVelocity!.abs() > 200) {
                            final swipeRight = details.primaryVelocity! > 0;
                            cardController.flip(swipeRight: swipeRight);
                            HapticFeedback.selectionClick();
                          }
                        },
                        child: SizedBox(
                          width: 96,
                          height: 144,
                          child: FlippableCard(
                            controller: cardController,
                            isBelow: false,
                            arrowLeft: 48.0,
                            front: WordMiniCardFront(
                              word: word,
                              card: specificCard,
                              onTap: navigateToDetail,
                            ),
                            back: WordMiniCardBack(
                              word: word,
                              card: specificCard,
                              onTap: navigateToDetail,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isMe
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF815BF5).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Text(
                          word,
                          style: TextStyle(
                            color: isMe ? Colors.white : AppColors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatMessageTime(message.time),
                            style: const TextStyle(
                              color: AppColors.onSurfaceMuted,
                              fontSize: 10,
                            ),
                          ),
                          if (message.isMe) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.done_all_rounded,
                              size: 12,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
