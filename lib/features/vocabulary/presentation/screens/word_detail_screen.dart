import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/word_card_model.dart';
import '../providers/vocabulary_provider.dart';
import '../../../profile/presentation/providers/settings_provider.dart';
import '../../../home/presentation/providers/navigation_provider.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class WordDetailScreen extends ConsumerStatefulWidget {
  final String selectedWord;
  final String? cardId;

  const WordDetailScreen({
    super.key,
    required this.selectedWord,
    this.cardId,
  });

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
          int selectedIndex = -1;
          if (widget.cardId != null) {
            selectedIndex = wordCards.indexWhere((w) => w.id == widget.cardId);
          }
          if (selectedIndex == -1) {
            selectedIndex = wordCards.indexWhere(
              (w) => w.word.toLowerCase() == widget.selectedWord.toLowerCase(),
            );
          }

          final List<WordCardModel> sortedWords = [];
          if (selectedIndex != -1) {
            final targetCard = wordCards[selectedIndex];
            sortedWords.add(targetCard);
            sortedWords.addAll(
              wordCards.where((w) => w.id != targetCard.id),
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
                    return GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
                          HapticFeedback.mediumImpact();
                          final creatorId = card.userId;
                          if (creatorId != null && creatorId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(userId: creatorId),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfileErrorScreen(),
                              ),
                            );
                          }
                        }
                      },
                      child: _WordCard(
                        wordCard: card,
                        gradientIndex: index,
                        isPlaying: _isPlaying && _playingAudioUrl == card.audioUrl,
                        onPlayTapped: () => _toggleAudio(card.audioUrl),
                      ),
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

class _WordCard extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends ConsumerState<_WordCard> {
  List<String> _assembledWords = [];
  List<String> _wordPool = [];
  List<String> _shuffledOptions = [];
  String? _selectedOption;
  bool _isAnswered = false;

  Future<void> _recordCorrectCard() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final user = ref.read(authProvider).user;
      if (user == null) return;

      await supabase.from('resolved_cards').upsert({
        'user_id': user.id,
        'card_id': widget.wordCard.id,
        'language': widget.wordCard.language ?? 'Inglés',
      }, onConflict: 'user_id,card_id');
      
      debugPrint('Tarjeta resuelta registrada: ${widget.wordCard.word}');
    } catch (e) {
      debugPrint('Error al registrar tarjeta resuelta: $e');
    }
  }

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

  static const Map<String, String> _languageFlags = {
    'Inglés': 'assets/flags/us.svg',
    'Francés': 'assets/flags/fr.svg',
    'Alemán': 'assets/flags/de.svg',
    'Italiano': 'assets/flags/it.svg',
    'Portugués': 'assets/flags/pt.svg',
    'Chino': 'assets/flags/cn.svg',
    'Japonés': 'assets/flags/jp.svg',
  };

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  @override
  void didUpdateWidget(covariant _WordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordCard.id != widget.wordCard.id) {
      _initializeQuiz();
    }
  }

  void _initializeQuiz() {
    final design = widget.wordCard.canvasDesign;
    final quizType = design?['quiz_type'] as String? ?? 'pregunta';
    final exampleSentence = widget.wordCard.exampleSentence ?? '';
    final quizHiddenWord = design?['quiz_hidden_word'] as String? ?? '';

    if (quizType == 'acomodar') {
      final cleanSentence = exampleSentence
          .replaceAll(RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()?¿¡]'), '');
      final words = cleanSentence
          .split(RegExp(r'\s+'))
          .map((w) => w.trim())
          .where((w) => w.isNotEmpty)
          .toList();

      final List<dynamic> distractorsRaw = design?['quiz_distractors'] as List<dynamic>? ?? [];
      final distractors = distractorsRaw.map((e) => e.toString()).toList();

      _wordPool = [...words, ...distractors]
          .where((w) => w.isNotEmpty)
          .toList()..shuffle();
      _assembledWords = [];
    } else if (quizType == 'completar') {
      final List<dynamic> distractorsRaw = design?['quiz_distractors'] as List<dynamic>? ?? [];
      final distractors = distractorsRaw.map((e) => e.toString()).toList();
      _shuffledOptions = [quizHiddenWord, ...distractors]
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()..shuffle();
      _selectedOption = null;
    }
    _isAnswered = false;
  }

  Future<void> _playFeedbackSound(bool isCorrect) async {
    final player = AudioPlayer();
    try {
      final source = isCorrect ? 'sounds/correct.mp3' : 'sounds/incorrect.wav';
      await player.play(AssetSource(source));
      player.onPlayerComplete.first.then((_) => player.dispose());
    } catch (e) {
      debugPrint('Error playing feedback sound: $e');
      player.dispose();
    }
  }

  String _getCompletarText(String originalText, String hiddenWord) {
    if (originalText.isEmpty || hiddenWord.isEmpty) return originalText;
    final regExp = RegExp(RegExp.escape(hiddenWord), caseSensitive: false);
    return originalText.replaceAll(regExp, '_____');
  }

  bool _checkAcomodarCorrect() {
    final cleanSentence = widget.wordCard.exampleSentence ?? '';
    final expectedWords = cleanSentence
        .replaceAll(RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()?¿¡]'), '')
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    if (_assembledWords.length != expectedWords.length) return false;

    for (int i = 0; i < expectedWords.length; i++) {
      if (_assembledWords[i].toLowerCase() != expectedWords[i].toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  Widget _buildWordChip({
    required String word,
    required bool isAssembled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isAssembled ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAssembled ? Colors.white : Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          word,
          style: TextStyle(
            color: isAssembled ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionView(String description) {
    return Container(
      key: const ValueKey('quiz_description_view'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.greenAccent[100], size: 16),
              const SizedBox(width: 6),
              const Text(
                'EXPLICACIÓN',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              height: 1.4,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

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
            color: glowColor.withValues(alpha: 0.35),
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
            color: glowColor.withValues(alpha: 0.4),
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
            color: glowColor.withValues(alpha: 0.55),
            blurRadius: 16,
            spreadRadius: 2.5,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
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
            color: glowColor.withValues(alpha: 0.6),
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
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: frameColor,
          width: borderWidth,
        ),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: child,
      ),
    );
  }

  Widget _buildHighlightText(String text, String keyword) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();

    if (lowerKeyword.isEmpty || !lowerText.contains(lowerKeyword)) {
      return Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontFamily: 'Inter',
        ),
      );
    }

    final int index = lowerText.indexOf(lowerKeyword);
    final String before = text.substring(0, index);
    final String match = text.substring(index, index + keyword.length);
    final String after = text.substring(index + keyword.length);

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontFamily: 'Inter',
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF86EFAC),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int gradIdx = widget.gradientIndex;
    if (widget.wordCard.canvasDesign != null && widget.wordCard.canvasDesign!['gradient_index'] != null) {
      final rawIndex = widget.wordCard.canvasDesign!['gradient_index'];
      if (rawIndex is num) {
        gradIdx = rawIndex.toInt();
      }
    }
    final gradient = _gradients[gradIdx % _gradients.length];

    final bool isTemp = widget.wordCard.id == 'temp';

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    Text(
                      widget.wordCard.word,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref.read(pendingWordProvider.notifier).state = widget.wordCard.word;
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
    if (widget.wordCard.canvasDesign != null && widget.wordCard.canvasDesign!['frame_type'] != null) {
      frameType = widget.wordCard.canvasDesign!['frame_type'] as String;
    }

    final languageName = widget.wordCard.language ?? 'Inglés';
    final formattedLanguageName = languageName.substring(0, 1).toUpperCase() + languageName.substring(1).toLowerCase();
    final flagAsset = _languageFlags[formattedLanguageName] ?? 'assets/flags/us.svg';

    final design = widget.wordCard.canvasDesign;
    final quizType = design?['quiz_type'] as String? ?? 'pregunta';
    final quizAnswer = design?['quiz_answer'] as String? ?? 'Sí';
    final quizHiddenWord = design?['quiz_hidden_word'] as String? ?? '';
    final exampleSentence = widget.wordCard.exampleSentence ?? '';
    final bool showCorrectSentence = quizType == 'acomodar' && _isAnswered && _checkAcomodarCorrect();
    final cardDescription = design?['description'] as String? ?? '';

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
              color: gradient[0].withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Stack(
        children: [
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      child: Text(
                        widget.wordCard.category?.toUpperCase() ?? 'VOCABULARY',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2.5),
                        child: SvgPicture.asset(
                          flagAsset,
                          width: 26,
                          height: 18,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.wordCard.word.isNotEmpty
                      ? '${widget.wordCard.word[0].toUpperCase()}${widget.wordCard.word.substring(1).toLowerCase()}'
                      : '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    letterSpacing: 1.5,
                  ),
                ),
                if (widget.wordCard.phonetic.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.wordCard.phonetic,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        if (widget.wordCard.imageUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: widget.wordCard.imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.white.withValues(alpha: 0.05),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.white.withValues(alpha: 0.05),
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.white30,
                                  size: 32,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: const Center(
                              child: Icon(
                                Icons.image_rounded,
                                color: Colors.white30,
                                size: 36,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (quizType != 'acomodar' || showCorrectSentence)
                  _buildHighlightText(
                    quizType == 'completar' && quizHiddenWord.isNotEmpty
                        ? _getCompletarText(exampleSentence, quizHiddenWord)
                        : exampleSentence,
                    widget.wordCard.word,
                  )
                else
                  Text(
                    'Escucha el audio y ordena las palabras',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Inter',
                    ),
                  ),
                const SizedBox(height: 12),
                if (quizType == 'acomodar' && !showCorrectSentence) ...[
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: _assembledWords.isEmpty
                          ? const Text(
                              'Toca las palabras de abajo para ordenar',
                              style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                            )
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _assembledWords.map((word) {
                                return _buildWordChip(
                                  word: word,
                                  isAssembled: true,
                                  onTap: () {
                                    if (_isAnswered) return;
                                    setState(() {
                                      _assembledWords.remove(word);
                                      _wordPool.add(word);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.wordCard.audioUrl != null && widget.wordCard.audioUrl!.isNotEmpty) ...[
                  Center(
                    child: GestureDetector(
                      onTap: widget.onPlayTapped,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1.0,
                        child: child,
                      ),
                    );
                  },
                  child: (_isAnswered && cardDescription.isNotEmpty)
                      ? _buildDescriptionView(cardDescription)
                      : Container(
                          key: const ValueKey('quiz_controls_view'),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (quizType == 'acomodar' && !showCorrectSentence) ...[
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: _wordPool.map((word) {
                                      return _buildWordChip(
                                        word: word,
                                        isAssembled: false,
                                        onTap: () {
                                          if (_isAnswered) return;
                                          setState(() {
                                            _wordPool.remove(word);
                                            _assembledWords.add(word);
                                          });

                                          final correct = _checkAcomodarCorrect();
                                          final cleanSentence = widget.wordCard.exampleSentence ?? '';
                                          final expectedWords = cleanSentence
                                              .replaceAll(RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()?¿¡]'), '')
                                              .split(RegExp(r'\s+'))
                                              .map((w) => w.trim())
                                              .where((w) => w.isNotEmpty)
                                              .toList();

                                          if (_assembledWords.length == expectedWords.length) {
                                            _playFeedbackSound(correct);
                                            setState(() {
                                              _isAnswered = true;
                                            });

                                            ScaffoldMessenger.of(context).clearSnackBars();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    Icon(
                                                      correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(correct ? '¡Excelente! Frase ordenada correctamente.' : '¡Incorrecto! Orden incorrecto.'),
                                                  ],
                                                ),
                                                backgroundColor: correct ? Colors.green : Colors.redAccent,
                                                duration: const Duration(milliseconds: 1500),
                                              ),
                                            );

                                            if (correct) {
                                              _recordCorrectCard();
                                            } else {
                                              Future.delayed(const Duration(milliseconds: 1600), () {
                                                if (mounted) {
                                                  setState(() {
                                                    _initializeQuiz();
                                                  });
                                                }
                                              });
                                            }
                                          }
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ] else if (quizType == 'completar') ...[
                                Row(
                                  children: _shuffledOptions.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final option = entry.value;
                                    final isSelected = _selectedOption == option;
                                    final isCorrect = option.toLowerCase() == quizHiddenWord.toLowerCase();

                                    Color buttonColor = Colors.white.withValues(alpha: 0.15);
                                    if (_selectedOption != null) {
                                      if (isCorrect) {
                                        buttonColor = Colors.green.withValues(alpha: 0.4);
                                      } else if (isSelected) {
                                        buttonColor = Colors.redAccent.withValues(alpha: 0.4);
                                      }
                                    }

                                    return Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(left: idx == 0 ? 0 : 6, right: idx == _shuffledOptions.length - 1 ? 0 : 6),
                                        child: GestureDetector(
                                          onTap: () {
                                            if (_selectedOption != null) return;
                                            setState(() {
                                              _selectedOption = option;
                                              _isAnswered = true;
                                            });
                                            _playFeedbackSound(isCorrect);

                                            ScaffoldMessenger.of(context).clearSnackBars();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    Icon(
                                                      isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(isCorrect ? '¡Correcto! Excelente trabajo.' : '¡Incorrecto! Inténtalo de nuevo.'),
                                                  ],
                                                ),
                                                backgroundColor: isCorrect ? Colors.green : Colors.redAccent,
                                                duration: const Duration(milliseconds: 1500),
                                              ),
                                            );

                                            if (isCorrect) {
                                              _recordCorrectCard();
                                            } else {
                                              Future.delayed(const Duration(milliseconds: 1600), () {
                                                if (mounted) {
                                                  setState(() {
                                                    _selectedOption = null;
                                                    _isAnswered = false;
                                                  });
                                                }
                                              });
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: buttonColor,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSelected
                                                    ? (isCorrect ? Colors.green : Colors.redAccent)
                                                    : Colors.white.withValues(alpha: 0.2),
                                                width: isSelected ? 2 : 1,
                                              ),
                                            ),
                                            child: Text(
                                              option,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ] else if (quizType == 'pregunta') ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _CardAction(
                                        icon: Icons.check_circle_outline_rounded,
                                        label: 'Sí',
                                        onTap: () {
                                          if (_isAnswered) return;
                                          final isCorrect = quizAnswer == 'Sí';
                                          setState(() {
                                            _isAnswered = true;
                                          });
                                          _playFeedbackSound(isCorrect);

                                          ScaffoldMessenger.of(context).clearSnackBars();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  Icon(
                                                    isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(isCorrect ? '¡Correcto! Excelente trabajo.' : '¡Incorrecto! Inténtalo de nuevo.'),
                                                ],
                                              ),
                                              backgroundColor: isCorrect ? Colors.green : Colors.redAccent,
                                              duration: const Duration(milliseconds: 1500),
                                            ),
                                          );

                                          if (isCorrect) {
                                            _recordCorrectCard();
                                          } else {
                                            Future.delayed(const Duration(milliseconds: 1600), () {
                                              if (mounted) {
                                                setState(() {
                                                  _isAnswered = false;
                                                });
                                              }
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _CardAction(
                                        icon: Icons.cancel_outlined,
                                        label: 'No',
                                        onTap: () {
                                          if (_isAnswered) return;
                                          final isCorrect = quizAnswer == 'No';
                                          setState(() {
                                            _isAnswered = true;
                                          });
                                          _playFeedbackSound(isCorrect);

                                          ScaffoldMessenger.of(context).clearSnackBars();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  Icon(
                                                    isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(isCorrect ? '¡Correcto! Excelente trabajo.' : '¡Incorrecto! Inténtalo de nuevo.'),
                                                ],
                                              ),
                                              backgroundColor: isCorrect ? Colors.green : Colors.redAccent,
                                              duration: const Duration(milliseconds: 1500),
                                            ),
                                          );

                                          if (isCorrect) {
                                            _recordCorrectCard();
                                          } else {
                                            Future.delayed(const Duration(milliseconds: 1600), () {
                                              if (mounted) {
                                                setState(() {
                                                  _isAnswered = false;
                                                });
                                              }
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
                const Spacer(),
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
