import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/chat_entity.dart';
import '../widgets/message_bubble.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../vocabulary/domain/models/word_card_model.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../../../vocabulary/presentation/screens/word_detail_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatEntity chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late List<MessageEntity> _messages;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.chat.messages);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _dismissOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showWordCard(String word, Offset globalPosition) {
    _dismissOverlay();

    final cleanWord =
        word.replaceAll(RegExp(r"[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ']"), '');
    if (cleanWord.length < 2) return;

    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 96.0;
    const cardHeight = 136.0;

    double left = globalPosition.dx - cardWidth / 2;
    double top = globalPosition.dy - cardHeight - 16;
    left = left.clamp(8.0, screenSize.width - cardWidth - 8);
    top =
        top.clamp(kToolbarHeight + 16.0, screenSize.height - cardHeight - 90);

    final cardController = FlippableCardController();

    _overlayEntry = OverlayEntry(
      builder: (_) => GestureDetector(
        onTap: _dismissOverlay,
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity!.abs() > 200) {
            final swipeRight = details.primaryVelocity! > 0;
            cardController.flip(swipeRight: swipeRight);
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: FlippableCard(
                controller: cardController,
                front: _WordMiniCardFront(
                  word: cleanWord,
                  onTap: () {
                    _dismissOverlay();
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            WordDetailScreen(selectedWord: cleanWord),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                  },
                ),
                back: _WordMiniCardBack(
                  word: cleanWord,
                  onTap: () {
                    _dismissOverlay();
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            WordDetailScreen(selectedWord: cleanWord),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(MessageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isMe: true,
        time: DateTime.now(),
      ));
    });

    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissOverlay,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              _Avatar(
                initials: widget.chat.initials,
                colorIndex: widget.chat.avatarColorIndex,
                size: 34,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chat.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.chat.isOnline)
                    const Text(
                      'en línea',
                      style: TextStyle(
                        color: AppColors.online,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.videocam_outlined),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.call_outlined),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) => MessageBubble(
                  message: _messages[index],
                  onWordTap: _showWordCard,
                ),
              ),
            ),
            _InputBar(
              controller: _controller,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      final hasText = widget.controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
              decoration: const InputDecoration(
                hintText: AppStrings.escribeMensaje,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                fillColor: AppColors.surfaceVariant,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _hasText ? const Color(0xFF0F172A) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _hasText ? widget.onSend : null,
              icon: const Icon(Icons.send_rounded),
              color: _hasText ? Colors.white : AppColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final int colorIndex;
  final double size;

  const _Avatar({
    required this.initials,
    required this.colorIndex,
    this.size = 54,
  });

  static const List<Color> _colors = AppColors.avatarColors;

  @override
  Widget build(BuildContext context) {
    final color = _colors[colorIndex % _colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        shape: BoxShape.circle,
        border: Border.all(color: color.withAlpha(77), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.32,
          ),
        ),
      ),
    );
  }
}

class _MiniCardBase extends StatelessWidget {
  final Widget child;
  final List<Widget> background;
  final VoidCallback onTap;

  const _MiniCardBase({
    required this.child,
    this.background = const [],
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 96,
          height: 136,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.6),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              ...background,
              Positioned(
                right: -14,
                top: -14,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.40),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordMiniCardFront extends ConsumerWidget {
  final String word;
  final VoidCallback onTap;

  const _WordMiniCardFront({required this.word, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordCardsAsync = ref.watch(wordCardsProvider);

    return _MiniCardBase(
      onTap: onTap,
      background: wordCardsAsync.when(
        data: (wordList) {
          WordCardModel? matchingCard;
          for (final w in wordList) {
            if (w.word.toLowerCase() == word.toLowerCase()) {
              matchingCard = w;
              break;
            }
          }

          if (matchingCard != null) {
            return [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.70,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: matchingCard.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.white.withOpacity(0.1),
                      ),
                      errorWidget: (context, url, error) => const SizedBox(),
                    ),
                  ),
                ),
              ),
            ];
          }
          return [];
        },
        loading: () => [],
        error: (error, _) => [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_stories_outlined,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(height: 8),
          Text(
            word,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.2,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                )
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: const Text(
              'Open',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordMiniCardBack extends ConsumerWidget {
  final String word;
  final VoidCallback onTap;

  const _WordMiniCardBack({required this.word, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordCardsAsync = ref.watch(wordCardsProvider);

    return _MiniCardBase(
      onTap: onTap,
      child: wordCardsAsync.when(
        data: (wordList) {
          WordCardModel? matchingCard;
          for (final w in wordList) {
            if (w.word.toLowerCase() == word.toLowerCase()) {
              matchingCard = w;
              break;
            }
          }

          final definition = matchingCard?.definition ?? 'Sin definición';
          final phonetic = matchingCard?.phonetic ?? '';

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.g_translate_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(height: 6),
              if (phonetic.isNotEmpty) ...[
                Text(
                  phonetic,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Text(
                      definition,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          )
                        ],
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Icon(
                Icons.flip_camera_android_outlined,
                color: Colors.white70,
                size: 14,
              ),
            ],
          );
        },
        loading: () => const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
        error: (error, _) => const Center(
          child: Text(
            'Error',
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
      ),
    );
  }
}

class FlippableCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final Duration duration;
  final FlippableCardController? controller;

  const FlippableCard({
    super.key,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 250),
    this.controller,
  });

  @override
  State<FlippableCard> createState() => _FlippableCardState();
}

class _FlippableCardState extends State<FlippableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFront = true;
  double _directionMultiplier = 1.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    widget.controller?._state = this;
  }

  void toggleCard({required bool swipeRight}) {
    setState(() {
      if (_isFront) {
        _directionMultiplier = swipeRight ? -1.0 : 1.0;
      } else {
        _directionMultiplier = swipeRight ? 1.0 : -1.0;
      }
    });

    if (_isFront) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double angle = _animation.value * math.pi * _directionMultiplier;
        final bool showFront = angle.abs() < math.pi / 2;

        final Matrix4 transform = Matrix4.identity()
          ..setEntry(3, 2, 0.002) // 3D perspective
          ..rotateY(angle);

        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: showFront
              ? widget.front
              : Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child: widget.back,
                ),
        );
      },
    );
  }
}

class FlippableCardController {
  _FlippableCardState? _state;
  void flip({required bool swipeRight}) => _state?.toggleCard(swipeRight: swipeRight);
}
