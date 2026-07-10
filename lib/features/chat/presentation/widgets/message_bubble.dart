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
  final Function(String messageId, String word, Offset globalPosition, Size wordSize) onWordTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.onWordTap,
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

    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. La Carta Flippable centradita con detector de deslizamiento
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) {}, // Bloquea el PageView del chat
              onHorizontalDragUpdate: (_) {}, // Bloquea el PageView del chat
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
                height: 144, // 136px card + 8px arrow
                child: FlippableCard(
                  controller: cardController,
                  isBelow: false, // La flecha está abajo apuntando al texto
                  arrowLeft: 48.0, // Eje central
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
            
            // 2. El globito de la palabra abajo
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF815BF5), Color(0xFF5A45FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF815BF5).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                word,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            
            // 3. Hora y check
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
