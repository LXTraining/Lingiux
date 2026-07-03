import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/word_card_model.dart';
import '../providers/vocabulary_provider.dart';
import '../../../profile/presentation/providers/settings_provider.dart';
import '../../../home/presentation/providers/navigation_provider.dart';

class WordDetailScreen extends ConsumerStatefulWidget {
  final String selectedWord;

  const WordDetailScreen({super.key, required this.selectedWord});

  @override
  ConsumerState<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends ConsumerState<WordDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  // Estado para la reproducción de audios remotos de las cartas
  final AudioPlayer _networkPlayer = AudioPlayer();
  String? _playingAudioUrl;
  bool _isPlaying = false;
  bool _hasPlayedInitialAudio = false;

  Future<void> _playAudio(String? url) async {
    if (url == null || url.isEmpty) return;

    try {
      await _networkPlayer.stop();
      setState(() {
        _playingAudioUrl = url;
        _isPlaying = true;
      });
      await _networkPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('Error al reproducir audio automáticamente: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Escuchar el estado del reproductor remoto para actualizar la interfaz
    _networkPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _networkPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playingAudioUrl = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _networkPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(String? url) async {
    if (url == null || url.isEmpty) return;

    try {
      if (_playingAudioUrl == url) {
        if (_isPlaying) {
          await _networkPlayer.pause();
        } else {
          await _networkPlayer.resume();
        }
      } else {
        await _networkPlayer.stop();
        setState(() {
          _playingAudioUrl = url;
        });
        await _networkPlayer.play(UrlSource(url));
      }
    } catch (e) {
      debugPrint('Error al reproducir audio de Supabase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordCardsAsync = ref.watch(wordCardsProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Word Cards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: wordCardsAsync.when(
        loading: () => const _WordCardsSkeleton(),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error al cargar tarjetas:\n$err',
                style: const TextStyle(color: AppColors.darkOnSurface, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(wordCardsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (wordCards) {
          if (wordCards.isEmpty) {
            return const Center(
              child: Text(
                'No hay tarjetas disponibles.',
                style: TextStyle(color: AppColors.darkOnSurfaceMuted),
              ),
            );
          }

          // Ordenar para mostrar la palabra seleccionada primero
          final selectedIndex = wordCards.indexWhere(
            (w) => w.word.toLowerCase() == widget.selectedWord.toLowerCase(),
          );

          final List<WordCardModel> sortedWords = [];
          if (selectedIndex != -1) {
            sortedWords.add(wordCards[selectedIndex]);
            sortedWords.addAll(
              wordCards.where(
                (w) => w.word.toLowerCase() != widget.selectedWord.toLowerCase(),
              ),
            );
          } else {
            // Si la palabra no está (por ejemplo si es inventada/custom), agregar un placeholder temporal
            sortedWords.add(
              WordCardModel(
                id: 'temp',
                word: widget.selectedWord,
                definition: 'Definición no encontrada para esta palabra.',
                phonetic: '/${widget.selectedWord.toLowerCase()}/',
                imageUrl: 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=600',
                createdAt: DateTime.now(),
              ),
            );
            sortedWords.addAll(wordCards);
          }

          // Reproducción automática de la primera carta en la primera carga si está activa
          if (!_hasPlayedInitialAudio) {
            _hasPlayedInitialAudio = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final autoPlay = ref.read(settingsProvider).autoPlayAudio;
              if (autoPlay && sortedWords.isNotEmpty) {
                _playAudio(sortedWords[0].audioUrl);
              }
            });
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.swipe_vertical_rounded,
                      color: AppColors.darkOnSurfaceMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Desliza verticalmente para explorar',
                      style: TextStyle(color: AppColors.darkOnSurfaceMuted, fontSize: 13),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(_currentPage % sortedWords.length) + 1} / ${sortedWords.length}',
                        style: const TextStyle(
                          color: AppColors.darkOnSurfaceMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _networkPlayer.stop();
                    setState(() {
                      _isPlaying = false;
                      _playingAudioUrl = null;
                    });

                    final autoPlay = ref.read(settingsProvider).autoPlayAudio;
                    final wordIndex = index % sortedWords.length;
                    final card = sortedWords[wordIndex];
                    if (autoPlay && card.audioUrl != null && card.audioUrl!.isNotEmpty) {
                      _playAudio(card.audioUrl);
                    }
                  },
                  itemBuilder: (context, index) {
                    final wordIndex = index % sortedWords.length;
                    final card = sortedWords[wordIndex];
                    return _WordCard(
                      wordCard: card,
                      gradientIndex: index,
                      isPlaying: _isPlaying && _playingAudioUrl == card.audioUrl,
                      onPlayTapped: () => _toggleAudio(card.audioUrl),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WordCard extends ConsumerWidget {
  final WordCardModel wordCard;
  final int gradientIndex;
  final bool isPlaying;
  final VoidCallback onPlayTapped;

  const _WordCard({
    required this.wordCard,
    required this.gradientIndex,
    required this.isPlaying,
    required this.onPlayTapped,
  });

  static const List<List<Color>> _gradients = [
    [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    [Color(0xFF0284C7), Color(0xFF6366F1)],
    [Color(0xFF059669), Color(0xFF0284C7)],
    [Color(0xFFD97706), Color(0xFFDC2626)],
    [Color(0xFFDB2777), Color(0xFF7C3AED)],
    [Color(0xFF0D9488), Color(0xFF2563EB)],
    [Color(0xFF7C3AED), Color(0xFFDB2777)],
    [Color(0xFF1D4ED8), Color(0xFF059669)],
  ];

  Widget _buildFrameDecoration(String type, Widget child, Color fallbackColor) {
    if (type == 'normal') {
      return child;
    }

    Color frameColor;
    Color glowColor;
    double borderWidth = 6.0;
    List<BoxShadow> shadows = [];

    switch (type) {
      case 'bronce':
        frameColor = const Color(0xFFCD7F32);
        glowColor = const Color(0xFF8B5A2B);
        shadows = [
          BoxShadow(
            color: glowColor.withOpacity(0.35),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ];
        break;
      case 'plata':
        frameColor = const Color(0xFFE0E0E0);
        glowColor = const Color(0xFF9E9E9E);
        shadows = [
          BoxShadow(
            color: glowColor.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 1.5,
          )
        ];
        break;
      case 'oro':
        frameColor = const Color(0xFFFFD700);
        glowColor = const Color(0xFFDAA520);
        shadows = [
          BoxShadow(
            color: glowColor.withOpacity(0.55),
            blurRadius: 16,
            spreadRadius: 2.5,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
        ];
        break;
      case 'neon':
        frameColor = const Color(0xFFEC4899);
        glowColor = const Color(0xFFEC4899);
        shadows = [
          BoxShadow(
            color: glowColor.withOpacity(0.6),
            blurRadius: 18,
            spreadRadius: 3.5,
          ),
        ];
        borderWidth = 5.0;
        break;
      default:
        return child;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: frameColor, width: borderWidth),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int gradIdx = gradientIndex;
    if (wordCard.canvasDesign != null && wordCard.canvasDesign!['gradient_index'] != null) {
      final rawIndex = wordCard.canvasDesign!['gradient_index'];
      if (rawIndex is num) {
        gradIdx = rawIndex.toInt();
      }
    }
    final gradient = _gradients[gradIdx % _gradients.length];

    final bool isTemp = wordCard.id == 'temp';

    if (isTemp) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Círculos de diseño abstractos y sutiles en el fondo
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Contenido principal de la tarjeta
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fila superior: etiqueta
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'CREAR CARTA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Icono central decorativo
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_outlined,
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Palabra clave
                    Text(
                      wordCard.word,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mensaje experto
                    Text(
                      'Esta palabra aún no cuenta con una tarjeta mnemotécnica en tu colección personal. Comienza a potenciar tu vocabulario creándola ahora mismo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),

                    // Botón para redirigir al editor
                    ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref.read(pendingWordProvider.notifier).state = wordCard.word;
                        ref.read(activeTabProvider.notifier).state = 2;
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      icon: Icon(Icons.edit_note_rounded, color: gradient[0]),
                      label: Text(
                        'Diseñar Tarjeta',
                        style: TextStyle(
                          color: gradient[0],
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    String frameType = 'normal';
    if (wordCard.canvasDesign != null && wordCard.canvasDesign!['frame_type'] != null) {
      frameType = wordCard.canvasDesign!['frame_type'] as String;
    }

    final cardBody = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          if (frameType == 'normal')
            BoxShadow(
              color: gradient[0].withOpacity(0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
        ],
      ),
        child: Stack(
          children: [
            // Círculos de diseño abstractos y sutiles en el fondo
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Contenido principal de la tarjeta
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fila superior: etiqueta de categoría e icono de audio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'VOCABULARY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                      if (wordCard.audioUrl != null && wordCard.audioUrl!.isNotEmpty)
                        GestureDetector(
                          onTap: onPlayTapped,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 1. Palabra clave (Centrada arriba)
                  Text(
                    wordCard.word,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Fonética (Centrada debajo de la palabra)
                  Text(
                    wordCard.phonetic,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Imagen representativa rectangular (Centrada)
                  Center(
                    child: Container(
                      height: 135,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: wordCard.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.white.withOpacity(0.1),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, err) => Container(
                            color: Colors.white.withOpacity(0.1),
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.white70,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Separador
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.18),
                  ),
                  const SizedBox(height: 12),

                  // 3. Tags (Centrados)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (wordCard.category != null && wordCard.category!.isNotEmpty) ...[
                        _Tag(label: wordCard.category!),
                        const SizedBox(width: 8),
                      ],
                      if (wordCard.language != null && wordCard.language!.isNotEmpty) ...[
                        _Tag(label: wordCard.language!),
                        const SizedBox(width: 8),
                      ],
                      if ((wordCard.category == null || wordCard.category!.isEmpty) &&
                          (wordCard.language == null || wordCard.language!.isEmpty))
                        const _Tag(label: 'Vocabulary'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Definición y frase de ejemplo (Centrada y Scrollable si es necesario)
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            wordCard.definition,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          if (wordCard.exampleSentence != null &&
                              wordCard.exampleSentence!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              '"${wordCard.exampleSentence}"',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13.5,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botones de acción en la parte inferior
                  Row(
                    children: [
                      Expanded(
                        child: _CardAction(
                          icon: Icons.bookmark_border_rounded,
                          label: 'Save',
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CardAction(
                          icon: Icons.quiz_outlined,
                          label: 'Practice',
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: _buildFrameDecoration(
        frameType,
        cardBody,
        gradient[0],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordCardsSkeleton extends StatefulWidget {
  const _WordCardsSkeleton();

  @override
  State<_WordCardsSkeleton> createState() => _WordCardsSkeletonState();
}

class _WordCardsSkeletonState extends State<_WordCardsSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceVariant,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 120,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.darkOnSurface.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.darkOnSurface.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 220,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.darkOnSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 100,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.darkOnSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    height: 1,
                    color: AppColors.darkOnSurface.withOpacity(0.08),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: List.generate(
                      3,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 70,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.darkOnSurface.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.darkOnSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.darkOnSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 150,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.darkOnSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.darkOnSurface.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.darkOnSurface.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
