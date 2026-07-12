import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/entities/chat_entity.dart';
import '../widgets/message_bubble.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_puzzle_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/services/audio_service.dart';
import '../../../vocabulary/domain/models/word_card_model.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../../../vocabulary/presentation/screens/word_detail_screen.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final ChatEntity chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  OverlayEntry? _overlayEntry;
  late final PageController _pageController;
  final Map<String, WordCardModel> _selectedCardsCache = {};
  bool _isFlagRibbonOpen = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _controller.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _dismissOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showWordCard(String messageId, String word, Offset globalPosition, Size wordSize) {
    _dismissOverlay();

    final cleanWord = word.replaceAll(RegExp(r"[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ']"), '');
    if (cleanWord.length < 2) return;

    final wordList = ref.read(wordCardsProvider).value ?? [];
    
    // Obtener todas las cartas que coinciden con esta palabra (case-insensitive)
    final matches = wordList.where((w) => w.word.toLowerCase() == cleanWord.toLowerCase()).toList();
    
    WordCardModel? selectedWordCard;
    if (matches.isNotEmpty) {
      final cacheKey = "${messageId}_${cleanWord.toLowerCase()}";
      if (_selectedCardsCache.containsKey(cacheKey)) {
        selectedWordCard = _selectedCardsCache[cacheKey];
      } else {
        // Seleccionar aleatoriamente una de las coincidencias
        selectedWordCard = matches[math.Random().nextInt(matches.length)];
        _selectedCardsCache[cacheKey] = selectedWordCard!;
      }
    }

    ref.read(audioServiceProvider).playTap();
    HapticFeedback.lightImpact();

    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 96.0;
    const cardHeight = 136.0;
    const spacing = 8.0;
    final safeAreaTop = MediaQuery.of(context).padding.top + kToolbarHeight;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final wordCenterX = globalPosition.dx;
    double left = wordCenterX - cardWidth / 2;
    double top = globalPosition.dy - cardHeight - spacing;

    // Si no hay suficiente espacio arriba, mostrar debajo de la palabra
    bool isBelow = false;
    if (top < safeAreaTop + 8.0) {
      top = globalPosition.dy + wordSize.height;
      isBelow = true;
    }

    left = left.clamp(8.0, screenSize.width - cardWidth - 8);
    top = top.clamp(
      safeAreaTop + 8.0,
      screenSize.height - cardHeight - safeAreaBottom - 16.0,
    );

    final arrowLeft = (wordCenterX - left).clamp(16.0, cardWidth - 16.0);

    final cardController = FlippableCardController();

    _overlayEntry = OverlayEntry(
      builder: (_) => _OverlayEntrance(
        isBelow: isBelow,
        left: left,
        top: top,
        onDismiss: _dismissOverlay,
        onShare: () {
          _dismissOverlay();
          _sendSharedCardMessage(cleanWord, selectedWordCard);
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity!.abs() > 200) {
            final swipeRight = details.primaryVelocity! > 0;
            cardController.flip(swipeRight: swipeRight);
            HapticFeedback.selectionClick();
          }
        },
        child: FlippableCard(
          controller: cardController,
          isBelow: isBelow,
          arrowLeft: arrowLeft,
          front: WordMiniCardFront(
            word: cleanWord,
            card: selectedWordCard,
            onTap: () {
              _dismissOverlay();
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      WordDetailScreen(
                        selectedWord: cleanWord,
                        cardId: selectedWordCard?.id,
                        conversationId: widget.chat.id,
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
            },
          ),
          back: WordMiniCardBack(
            word: cleanWord,
            card: selectedWordCard,
            onTap: () {
              _dismissOverlay();
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      WordDetailScreen(
                        selectedWord: cleanWord,
                        cardId: selectedWordCard?.id,
                        conversationId: widget.chat.id,
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
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final currentUserId = ref.read(authProvider).user?.id ?? '';
    ref.read(chatServiceProvider).sendMessage(widget.chat.id, currentUserId, text);
    _controller.clear();
  }

  void _sendSharedCardMessage(String word, WordCardModel? card) {
    final currentUserId = ref.read(authProvider).user?.id ?? '';
    final textToSend = card != null ? '[CARD]:$word:${card.id}' : '[CARD]:$word';
    ref.read(chatServiceProvider).sendMessage(
      widget.chat.id,
      currentUserId,
      textToSend,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatsListAsync = ref.watch(chatsProvider);
    final chatsList = chatsListAsync.value?.cast<ChatEntity>();
    final chatEntity = chatsList?.firstWhere(
      (c) => c.id == widget.chat.id,
      orElse: () => widget.chat,
    ) ?? widget.chat;

    return GestureDetector(
      onTap: _dismissOverlay,
      child: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildConversationPage(context, chatEntity),
          _buildInfoPage(context),
        ],
      ),
    );
  }

  Widget _buildConversationPage(BuildContext context, ChatEntity chatEntity) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _Avatar(
              initials: widget.chat.initials,
              colorIndex: widget.chat.avatarColorIndex,
              size: 34,
              avatarUrl: widget.chat.avatarUrl,
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
                    style: TextStyle(color: AppColors.online, fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isFlagRibbonOpen = !_isFlagRibbonOpen;
              });
            },
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: _buildFlagCircle(chatEntity.activeNationality, size: 28),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              _pageController.animateToPage(
                1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isFlagRibbonOpen) _buildFlagRibbon(context, chatEntity),
          Expanded(
            child: ref.watch(messagesProvider(widget.chat.id)).when(
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });
                if (messages.isEmpty) {
                  return const Center(child: Text('No hay mensajes aún. ¡Comienza a chatear!'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => MessageBubble(
                    message: messages[index],
                    conversationId: widget.chat.id,
                    onWordTap: _showWordCard,
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (error, stack) => Center(child: Text('Error al cargar mensajes: $error')),
            ),
          ),
          _InputBar(controller: _controller, onSend: _sendMessage),
        ],
      ),
    );
  }

  Widget _buildFlagCircle(String nationality, {double size = 26}) {
    final flagPath = 'assets/flags/${nationality.toLowerCase()}.svg';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: ClipOval(
        child: SvgPicture.asset(
          flagPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => Container(color: Colors.grey[300]),
        ),
      ),
    );
  }

  Widget _buildFlagRibbon(BuildContext context, ChatEntity chatEntity) {
    final currentNationality = chatEntity.activeNationality;
    final nationalities = ['us', 'mx', 'fr', 'de', 'it', 'br'];

    return Container(
      height: 62,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: nationalities.length,
        itemBuilder: (context, index) {
          final nat = nationalities[index];
          final isSelected = nat.toLowerCase() == currentNationality.toLowerCase();

          return GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              setState(() {
                _isFlagRibbonOpen = false;
              });
              await ref.read(chatServiceProvider).updateActiveNationality(chatEntity.id, nat);
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 2.0,
                  ),
                ),
                child: _buildFlagCircle(nat, size: 32),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoPage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        ),
        title: const Text('Detalles del Chat'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Big Avatar
              Hero(
                tag: 'chat_avatar_${widget.chat.id}',
                child: _Avatar(
                  initials: widget.chat.initials,
                  colorIndex: widget.chat.avatarColorIndex,
                  size: 96,
                  avatarUrl: widget.chat.avatarUrl,
                ),
              ),
              const SizedBox(height: 24),
              // Chat Name
              Text(
                widget.chat.name,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              // Online / Offline Status Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.chat.isOnline
                      ? AppColors.online.withValues(alpha: 0.1)
                      : AppColors.onSurfaceMuted.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.chat.isOnline ? AppColors.online : AppColors.onSurfaceMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.chat.isOnline ? 'En línea' : 'Desconectado',
                      style: TextStyle(
                        color: widget.chat.isOnline ? AppColors.online : AppColors.onSurfaceMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Rompecabezas Compartido
              _ChatPuzzleWidget(conversationId: widget.chat.id),
              const SizedBox(height: 40),
              // Back hint
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 16,
                    color: AppColors.onSurfaceMuted.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Desliza a la derecha para volver al chat',
                    style: TextStyle(
                      color: AppColors.onSurfaceMuted.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.swipe_left_alt_rounded,
                    size: 16,
                    color: AppColors.onSurfaceMuted.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ],
          ),
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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



class _ChatPuzzleWidget extends ConsumerWidget {
  final String conversationId;

  const _ChatPuzzleWidget({
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puzzleAsync = ref.watch(chatPuzzleProvider(conversationId));

    return puzzleAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error al cargar rompecabezas: $err',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
      data: (puzzle) {
        if (puzzle == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final points = puzzle['points'] as int;
        final totalPieces = puzzle['total_pieces'] as int;
        final imageUrl = puzzle['image_url'] as String;
        final List<int> pieceOrder = List<int>.from(puzzle['piece_order'] as List);

        final int unlockedCount = (points ~/ 3).clamp(0, totalPieces);
        final Set<int> unlockedPieces = pieceOrder.take(unlockedCount).toSet();
        final bool isCompleted = unlockedCount >= totalPieces;

        // Progress metrics
        final double overallProgress = unlockedCount / totalPieces;
        final int pointsToNextPiece = 3 - (points % 3);
        final String progressText = isCompleted 
            ? '¡Rompecabezas completado!' 
            : 'Faltan $pointsToNextPiece pts para la siguiente pieza (1 respuesta correcta = 1 pt)';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ROMPECABEZAS COMPARTIDO',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '$unlockedCount / $totalPieces piezas',
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Jigsaw Grid Layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final puzzleWidth = constraints.maxWidth;
                  final puzzleHeight = puzzleWidth * 3 / 4; // Aspect Ratio 4:3
                  final xCount = 4;
                  final yCount = 3;
                  final pieceWidth = puzzleWidth / xCount;
                  final pieceHeight = puzzleHeight / yCount;

                  return Container(
                    width: puzzleWidth,
                    height: puzzleHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Base Full Image
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.surfaceVariant,
                                child: const Center(
                                  child: CircularProgressIndicator(color: AppColors.primary),
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                            ),
                          ),

                          // Covering grid of locked pieces and borders
                          for (int y = 0; y < yCount; y++)
                            for (int x = 0; x < xCount; x++) ...[
                              // Grid Cell
                              _buildGridCell(
                                x: x,
                                y: y,
                                xCount: xCount,
                                yCount: yCount,
                                pieceWidth: pieceWidth,
                                pieceHeight: pieceHeight,
                                index: y * xCount + x,
                                unlockedPieces: unlockedPieces,
                              ),
                            ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: overallProgress,
                  color: const Color(0xFF22C55E),
                  backgroundColor: AppColors.border.withValues(alpha: 0.3),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                progressText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),

              if (isCompleted) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final supabase = ref.read(supabaseClientProvider);
                    await resetPuzzle(supabase, conversationId);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    'CARGAR NUEVO ROMPECABEZAS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridCell({
    required int x,
    required int y,
    required int xCount,
    required int yCount,
    required double pieceWidth,
    required double pieceHeight,
    required int index,
    required Set<int> unlockedPieces,
  }) {
    final isUnlocked = unlockedPieces.contains(index);

    return Positioned(
      left: x * pieceWidth,
      top: y * pieceHeight,
      width: pieceWidth,
      height: pieceHeight,
      child: Stack(
        children: [
          // Locked Piece Overlay
          if (!isUnlocked)
            Positioned.fill(
              child: ClipPath(
                clipper: JigsawPieceClipper(
                  x: x,
                  y: y,
                  xCount: xCount,
                  yCount: yCount,
                ),
                child: Container(
                  color: AppColors.background.withValues(alpha: 0.96),
                  child: Center(
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: AppColors.onSurfaceMuted.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),

          // Interlocking borders painted on top (both locked and unlocked)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: JigsawBorderPainter(
                  x: x,
                  y: y,
                  xCount: xCount,
                  yCount: yCount,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class JigsawPieceClipper extends CustomClipper<Path> {
  final int x;
  final int y;
  final int xCount;
  final int yCount;

  JigsawPieceClipper({
    required this.x,
    required this.y,
    required this.xCount,
    required this.yCount,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Start at top-left
    path.moveTo(0, 0);

    // 1. Top edge
    if (y == 0) {
      path.lineTo(w, 0);
    } else {
      final isTab = ((x + (y - 1)) % 2 == 0);
      _drawHorizontalTab(path, 0, w, w, h, isTab, top: true);
    }

    // 2. Right edge
    if (x == xCount - 1) {
      path.lineTo(w, h);
    } else {
      final isTab = ((x + y) % 2 == 0);
      _drawVerticalTab(path, w, 0, h, w, isTab, right: true);
    }

    // 3. Bottom edge
    if (y == yCount - 1) {
      path.lineTo(0, h);
    } else {
      final isTab = ((x + y) % 2 == 0);
      _drawHorizontalTab(path, w, 0, w, h, isTab, top: false);
    }

    // 4. Left edge
    if (x == 0) {
      path.lineTo(0, 0);
    } else {
      final isTab = (((x - 1) + y) % 2 == 0);
      _drawVerticalTab(path, 0, h, 0, 0, isTab, right: false);
    }

    path.close();
    return path;
  }

  void _drawHorizontalTab(Path path, double startX, double endX, double w, double h, bool isTab, {required bool top}) {
    final direction = top ? (isTab ? -1.0 : 1.0) : (isTab ? 1.0 : -1.0);
    final length = endX - startX;
    final centerY = top ? 0.0 : h;
    final tabSize = h * 0.18; // tab height

    final p0 = Offset(startX + length * 0.35, centerY);
    final p1 = Offset(startX + length * 0.35, centerY + tabSize * direction);
    final p2 = Offset(startX + length * 0.45, centerY + tabSize * direction);
    final p3 = Offset(startX + length * 0.45, centerY + tabSize * 0.6 * direction);
    
    final p4 = Offset(startX + length * 0.5, centerY + tabSize * 1.5 * direction); // tip of tab
    
    final p5 = Offset(startX + length * 0.55, centerY + tabSize * 0.6 * direction);
    final p6 = Offset(startX + length * 0.55, centerY + tabSize * direction);
    final p7 = Offset(startX + length * 0.65, centerY + tabSize * direction);
    final p8 = Offset(startX + length * 0.65, centerY);

    path.lineTo(p0.dx, p0.dy);
    path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    path.cubicTo(p4.dx, p4.dy, p4.dx, p4.dy, p5.dx, p5.dy);
    path.cubicTo(p6.dx, p6.dy, p7.dx, p7.dy, p8.dx, p8.dy);
    path.lineTo(endX, centerY);
  }

  void _drawVerticalTab(Path path, double startX, double startY, double endY, double w, bool isTab, {required bool right}) {
    final direction = right ? (isTab ? 1.0 : -1.0) : (isTab ? -1.0 : 1.0);
    final length = endY - startY; // positive going down
    final centerX = right ? w : 0.0;
    final tabSize = w * 0.18;

    final p0 = Offset(centerX, startY + length * 0.35);
    final p1 = Offset(centerX + tabSize * direction, startY + length * 0.35);
    final p2 = Offset(centerX + tabSize * direction, startY + length * 0.45);
    final p3 = Offset(centerX + tabSize * 0.6 * direction, startY + length * 0.45);
    
    final p4 = Offset(centerX + tabSize * 1.5 * direction, startY + length * 0.5); // tip
    
    final p5 = Offset(centerX + tabSize * 0.6 * direction, startY + length * 0.55);
    final p6 = Offset(centerX + tabSize * direction, startY + length * 0.55);
    final p7 = Offset(centerX + tabSize * direction, startY + length * 0.65);
    final p8 = Offset(centerX, startY + length * 0.65);

    path.lineTo(p0.dx, p0.dy);
    path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    path.cubicTo(p4.dx, p4.dy, p4.dx, p4.dy, p5.dx, p5.dy);
    path.cubicTo(p6.dx, p6.dy, p7.dx, p7.dy, p8.dx, p8.dy);
    path.lineTo(centerX, endY);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class JigsawBorderPainter extends CustomPainter {
  final int x;
  final int y;
  final int xCount;
  final int yCount;

  JigsawBorderPainter({
    required this.x,
    required this.y,
    required this.xCount,
    required this.yCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final clipper = JigsawPieceClipper(x: x, y: y, xCount: xCount, yCount: yCount);
    final path = clipper.getClip(size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Avatar extends StatelessWidget {
  final String initials;
  final int colorIndex;
  final double size;
  final String? avatarUrl;

  const _Avatar({
    required this.initials,
    required this.colorIndex,
    this.size = 54,
    this.avatarUrl,
  });

  static const List<Color> _colors = AppColors.avatarColors;

  @override
  Widget build(BuildContext context) {
    final color = _colors[colorIndex % _colors.length];
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        backgroundColor: color.withAlpha(38),
        backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
            ? NetworkImage(avatarUrl!)
            : null,
        child: avatarUrl == null || avatarUrl!.isEmpty
            ? Text(
                initials,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.32,
                ),
              )
            : null,
      ),
    );
  }
}

class MiniCardBase extends StatelessWidget {
  final Widget child;
  final List<Widget> background;
  final VoidCallback onTap;

  const MiniCardBase({
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

class WordMiniCardFront extends ConsumerWidget {
  final String word;
  final WordCardModel? card;
  final VoidCallback onTap;

  const WordMiniCardFront({
    required this.word,
    this.card,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WordCardModel? matchingCard = card;

    if (matchingCard != null) {
      return MiniCardBase(
        onTap: onTap,
        background: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: matchingCard.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.white.withOpacity(0.1)),
                  errorWidget: (context, url, error) => const SizedBox(),
                ),
              ),
            ),
          ),
        ],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_stories_outlined,
              color: Colors.white,
              size: 22,
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

    final wordCardsAsync = ref.watch(wordCardsProvider);

    return MiniCardBase(
      onTap: onTap,
      background: wordCardsAsync.when(
        data: (wordList) {
          WordCardModel? fallbackCard;
          for (final w in wordList) {
            if (w.word.toLowerCase() == word.toLowerCase()) {
              fallbackCard = w;
              break;
            }
          }

          if (fallbackCard != null) {
            return [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.70,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: fallbackCard.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.white.withOpacity(0.1)),
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
      child: wordCardsAsync.when(
        data: (wordList) {
          final hasCard = wordList.any((w) => w.word.toLowerCase() == word.toLowerCase());

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasCard ? Icons.auto_stories_outlined : Icons.add_circle_outline_rounded,
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
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasCard ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  hasCard ? 'Open' : '+ Crear',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const SizedBox(),
        error: (_, __) => const SizedBox(),
      ),
    );
  }
}

class WordMiniCardBack extends ConsumerWidget {
  final String word;
  final WordCardModel? card;
  final VoidCallback onTap;

  const WordMiniCardBack({
    required this.word,
    this.card,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WordCardModel? matchingCard = card;

    if (matchingCard != null) {
      final definition = matchingCard.definition;
      final phonetic = matchingCard.phonetic;

      return MiniCardBase(
        onTap: onTap,
        child: Column(
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
                  color: Colors.white.withValues(alpha: 0.8),
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
                        ),
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
        ),
      );
    }

    final wordCardsAsync = ref.watch(wordCardsProvider);

    return MiniCardBase(
      onTap: onTap,
      child: wordCardsAsync.when(
        data: (wordList) {
          WordCardModel? fallbackCard;
          for (final w in wordList) {
            if (w.word.toLowerCase() == word.toLowerCase()) {
              fallbackCard = w;
              break;
            }
          }

          final hasCard = fallbackCard != null;
          final definition = hasCard
              ? fallbackCard.definition
              : 'Esta palabra no tiene tarjeta aún. ¡Toca aquí para crearla y memorizarla!';
          final phonetic = hasCard ? fallbackCard.phonetic : '';

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasCard ? Icons.g_translate_outlined : Icons.style_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(height: 6),
              if (phonetic.isNotEmpty) ...[
                Text(
                  phonetic,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
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
                          ),
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
  final bool isBelow;
  final double arrowLeft;

  const FlippableCard({
    super.key,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 250),
    this.controller,
    required this.isBelow,
    required this.arrowLeft,
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

        final cardWidget = showFront
            ? widget.front
            : Transform(
                transform: Matrix4.identity()..rotateY(math.pi),
                alignment: Alignment.center,
                child: widget.back,
              );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isBelow) ...[
              // Flecha apuntando hacia arriba rotando sobre sí misma
              Padding(
                padding: EdgeInsets.only(left: widget.arrowLeft - 6.0),
                child: Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: CustomPaint(
                    size: const Size(12, 8),
                    painter: ArrowPainter(
                      color: const Color(0xFF7C3AED),
                      isBelow: true,
                    ),
                  ),
                ),
              ),
            ],
            // La tarjeta flippable rotando sobre su propio centro
            Transform(
              transform: transform,
              alignment: Alignment.center,
              child: cardWidget,
            ),
            if (!widget.isBelow) ...[
              // Flecha apuntando hacia abajo rotando sobre sí misma
              Padding(
                padding: EdgeInsets.only(left: widget.arrowLeft - 6.0),
                child: Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: CustomPaint(
                    size: const Size(12, 8),
                    painter: ArrowPainter(
                      color: const Color(0xFF5B21B6),
                      isBelow: false,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class FlippableCardController {
  _FlippableCardState? _state;
  void flip({required bool swipeRight}) =>
      _state?.toggleCard(swipeRight: swipeRight);
}

class _OverlayEntrance extends StatefulWidget {
  final Widget child;
  final bool isBelow;
  final double left;
  final double top;
  final VoidCallback onDismiss;
  final VoidCallback onShare;
  final GestureDragEndCallback? onHorizontalDragEnd;

  const _OverlayEntrance({
    required this.child,
    required this.isBelow,
    required this.left,
    required this.top,
    required this.onDismiss,
    required this.onShare,
    this.onHorizontalDragEnd,
  });

  @override
  State<_OverlayEntrance> createState() => _OverlayEntranceState();
}

class _OverlayEntranceState extends State<_OverlayEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _backdropOpacityAnimation;
  bool _isDismissing = false;
  bool _showToolbar = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _backdropOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 0.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<double>(
      begin: widget.isBelow ? -8.0 : 8.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  void _handleDismiss() {
    if (_isDismissing) return;
    setState(() {
      _isDismissing = true;
    });
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleDismiss,
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: widget.onHorizontalDragEnd,
      child: Stack(
        children: [
          // Fondo oscuro animado (Backdrop)
          AnimatedBuilder(
            animation: _backdropOpacityAnimation,
            builder: (context, child) {
              return Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(
                    _backdropOpacityAnimation.value,
                  ),
                ),
              );
            },
          ),
          // La carta animada posicionada
          Positioned(
            left: widget.left,
            top: widget.top,
            child: GestureDetector(
              onTap: () {}, // Previene cerrar al tocar dentro de la carta
              onLongPress: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _showToolbar = !_showToolbar;
                });
              },
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        alignment: widget.isBelow
                            ? Alignment.topCenter
                            : Alignment.bottomCenter,
                        child: widget.child,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // Cinta de opciones (Toolbar) animada con suavidad al aparecer/desaparecer
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            left: widget.left + (96.0 / 2) - (100.0 / 2),
            top: _showToolbar
                ? (widget.isBelow
                    ? widget.top + 144.0 + 8.0
                    : widget.top - 36.0 - 8.0)
                : (widget.isBelow
                    ? widget.top + 144.0
                    : widget.top - 36.0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _showToolbar ? 1.0 : 0.0,
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !_showToolbar,
                child: _buildToolbar(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      width: 100,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1A30).withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onShare,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.send_rounded, color: Colors.white, size: 14),
              SizedBox(width: 6),
              Text(
                'Compartir',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArrowPainter extends CustomPainter {
  final Color color;
  final bool isBelow;

  ArrowPainter({required this.color, required this.isBelow});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isBelow) {
      // Triángulo apuntando hacia ARRIBA
      path.moveTo(size.width / 2, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      // Triángulo apuntando hacia ABAJO
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
