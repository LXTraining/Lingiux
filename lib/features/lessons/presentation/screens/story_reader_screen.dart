import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../vocabulary/domain/models/word_card_model.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../../../chat/presentation/screens/chat_detail_screen.dart';
import '../../domain/models/story_model.dart';
import '../widgets/story_background_widget.dart';

class StoryReaderScreen extends ConsumerStatefulWidget {
  final StoryModel story;
  const StoryReaderScreen({super.key, required this.story});

  @override
  ConsumerState<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends ConsumerState<StoryReaderScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  
  List<StoryToken> _tokens = [];
  String _cleanedText = '';
  
  bool _isPlaying = false;
  int _currentWordIndex = -1;
  double _speechRate = 0.5; // flutter_tts rate: 0.5 es la velocidad normal en Android/iOS
  bool _isGrammarHighlightEnabled = true;
  double _fontSize = 16.0;

  OverlayEntry? _overlayEntry;

  // Variables para la simulación del Karaoke por aproximación (Fallback)
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _parseStoryContent();
    _initTts();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _dismissOverlay();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      _fallbackTimer?.cancel();
      
      // Encontrar la primera palabra para marcarla justo cuando inicia el audio real
      int firstWordIdx = -1;
      for (int i = 0; i < _tokens.length; i++) {
        if (_tokens[i].isWord) {
          firstWordIdx = i;
          break;
        }
      }

      setState(() {
        _isPlaying = true;
        _currentWordIndex = firstWordIdx;
      });

      // Arrancar predicción inmediata para evitar lag.
      // Si la plataforma soporta eventos nativos, estos corregirán y sincronizarán la predicción sobre la marcha.
      _startFallbackTimer();
    });

    _flutterTts.setCompletionHandler(() {
      _fallbackTimer?.cancel();
      setState(() {
        _isPlaying = false;
        _currentWordIndex = -1;
      });
    });

    _flutterTts.setErrorHandler((msg) {
      _fallbackTimer?.cancel();
      setState(() {
        _isPlaying = false;
        _currentWordIndex = -1;
      });
    });

    // Cambios de progreso de lectura (iluminar palabra)
    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      debugPrint('TTS Progress Callback: start=$start, end=$end, word=$word');

      int activeIndex = -1;
      for (int i = 0; i < _tokens.length; i++) {
        final t = _tokens[i];
        if (t.isWord && start >= t.startOffset && start < t.endOffset) {
          activeIndex = i;
          break;
        }
      }

      if (activeIndex == -1) {
        // Buscador tolerante de aproximación por si hay desviaciones de caracteres
        int minDistance = 9999;
        for (int i = 0; i < _tokens.length; i++) {
          final t = _tokens[i];
          if (t.isWord) {
            final distance = (t.startOffset - start).abs();
            if (distance < minDistance) {
              minDistance = distance;
              activeIndex = i;
            }
          }
        }
        if (minDistance > 5) {
          activeIndex = -1;
        }
      }

      if (activeIndex != -1 && activeIndex != _currentWordIndex) {
        setState(() {
          _currentWordIndex = activeIndex;
        });
        // Sincronizar el temporizador de predicción con la posición real reportada
        _scheduleNextWordFallback();
      }
    });
  }

  void _parseStoryContent() {
    final regExp = RegExp(
      r'\[(v|n|adj|adv):([^\]]+)\]|([a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ]+)|([^a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ\s]+)|(\s+)',
      multiLine: true,
    );

    final List<StoryToken> tokens = [];
    final StringBuffer cleanedBuffer = StringBuffer();
    final matches = regExp.allMatches(widget.story.content);

    for (final match in matches) {
      final start = cleanedBuffer.length;
      if (match.group(1) != null) {
        // Palabra etiquetada gramaticalmente
        final tag = match.group(1);
        final word = match.group(2)!;
        cleanedBuffer.write(word);

        String? category;
        if (tag == 'v') {
          category = 'VERBO';
        } else if (tag == 'n') {
          category = 'SUSTANTIVO';
        } else if (tag == 'adj') {
          category = 'ADJETIVO';
        } else if (tag == 'adv') {
          category = 'ADVERBIO';
        }

        tokens.add(StoryToken(
          text: word,
          category: category,
          isWord: true,
          startOffset: start,
          endOffset: cleanedBuffer.length,
        ));
      } else if (match.group(3) != null) {
        // Palabra normal
        final word = match.group(3)!;
        cleanedBuffer.write(word);
        tokens.add(StoryToken(
          text: word,
          category: null,
          isWord: true,
          startOffset: start,
          endOffset: cleanedBuffer.length,
        ));
      } else {
        // Signo o Espacio
        final other = match.group(0)!;
        cleanedBuffer.write(other);
        tokens.add(StoryToken(
          text: other,
          category: null,
          isWord: false,
          startOffset: start,
          endOffset: cleanedBuffer.length,
        ));
      }
    }

    setState(() {
      _tokens = tokens;
      _cleanedText = cleanedBuffer.toString();
    });
  }

  Future<void> _speak() async {
    if (_isPlaying) {
      await _flutterTts.pause();
      _fallbackTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      String ttsLang = 'en-US';
      final langLower = widget.story.language.toLowerCase();
      if (langLower.contains('es') || langLower.contains('span')) {
        ttsLang = 'es-ES';
      } else if (langLower.contains('fr')) {
        ttsLang = 'fr-FR';
      } else if (langLower.contains('de') || langLower.contains('alem')) {
        ttsLang = 'de-DE';
      } else if (langLower.contains('it')) {
        ttsLang = 'it-IT';
      } else if (langLower.contains('port')) {
        ttsLang = 'pt-PT';
      }

      await _flutterTts.setLanguage(ttsLang);
      await _flutterTts.setSpeechRate(_speechRate);
      
      _fallbackTimer?.cancel();

      // No establecemos _isPlaying ni _currentWordIndex aquí. Esperamos a que setStartHandler
      // sea disparado por el sistema operativo cuando el audio empiece a sonar realmente,
      // eliminando por completo cualquier desfase o lag percibido.
      await _flutterTts.speak(_cleanedText);
    }
  }

  Future<void> _stop() async {
    await _flutterTts.stop();
    _fallbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _currentWordIndex = -1;
    });
  }

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    if (!_isPlaying) return;

    // Si aún no ha iniciado el resaltado, marcar la primera palabra
    if (_currentWordIndex == -1) {
      for (int i = 0; i < _tokens.length; i++) {
        if (_tokens[i].isWord) {
          setState(() {
            _currentWordIndex = i;
          });
          break;
        }
      }
    }

    _scheduleNextWordFallback();
  }

  void _scheduleNextWordFallback() {
    _fallbackTimer?.cancel();
    if (!_isPlaying || _currentWordIndex == -1) return;

    // Encontrar el índice de la siguiente palabra
    int nextIndex = -1;
    for (int i = _currentWordIndex + 1; i < _tokens.length; i++) {
      if (_tokens[i].isWord) {
        nextIndex = i;
        break;
      }
    }

    if (nextIndex == -1) {
      // Llegó al final del texto, detener
      _stop();
      return;
    }

    final currentWordText = _tokens[_currentWordIndex].text;
    
    // Cálculo estimado de milisegundos por palabra basado en la longitud y el speech rate de flutter_tts.
    // 0.5 es la velocidad media de referencia.
    final wordDurationMs = ((currentWordText.length * 95) / (_speechRate / 0.5)).clamp(220.0, 1600.0).toInt();

    _fallbackTimer = Timer(Duration(milliseconds: wordDurationMs), () {
      if (mounted && _isPlaying) {
        setState(() {
          _currentWordIndex = nextIndex;
        });
        _scheduleNextWordFallback();
      }
    });
  }

  void _dismissOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showWordCard(String word, WordCardModel? card, Offset wordCenter, Size wordSize) {
    _dismissOverlay();

    final cleanWord = word.replaceAll(RegExp(r"[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ']"), '');
    if (cleanWord.length < 2) return;

    // Obtener la lista de cartas del provider
    final wordList = ref.read(wordCardsProvider).value ?? [];
    
    // Obtener todas las cartas que coinciden con esta palabra (case-insensitive)
    final matches = wordList.where((w) => w.word.toLowerCase() == cleanWord.toLowerCase()).toList();
    
    WordCardModel? selectedWordCard = card;
    if (selectedWordCard == null && matches.isNotEmpty) {
      selectedWordCard = matches.first;
    }

    if (selectedWordCard == null) return;

    ref.read(audioServiceProvider).playTap();
    HapticFeedback.lightImpact();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    const cardWidth = 280.0;
    const cardHeight = 140.0;

    double left = wordCenter.dx - (cardWidth / 2);
    left = left.clamp(16.0, screenWidth - cardWidth - 16.0);

    bool isBelow = true;
    double top = wordCenter.dy + wordSize.height + 8.0;

    if (top + cardHeight > screenHeight - 100) {
      isBelow = false;
      top = wordCenter.dy - cardHeight - 8.0;
    }

    final arrowLeft = (wordCenter.dx - left).clamp(16.0, cardWidth - 16.0);

    _overlayEntry = OverlayEntry(
      builder: (_) => OverlayEntrance(
        left: left,
        top: top,
        isBelow: isBelow,
        onDismiss: _dismissOverlay,
        onShare: () {},
        child: SizedBox(
          width: cardWidth,
          height: cardHeight + 8.0,
          child: StoryExercisePopup(
            card: selectedWordCard!,
            allCards: wordList,
            isBelow: isBelow,
            arrowLeft: arrowLeft,
            onDismiss: _dismissOverlay,
            audioService: ref.read(audioServiceProvider),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Color _getCategoryColor(String category, Color defaultColor) {
    switch (category.toUpperCase()) {
      case 'VERBO':
        return const Color(0xFFEF4444); // Rojo coral
      case 'SUSTANTIVO':
        return const Color(0xFF10B981); // Verde esmeralda
      case 'ADJETIVO':
        return const Color(0xFF38BDF8); // Lighter blue for better contrast
      case 'ADVERBIO':
        return const Color(0xFFF59E0B); // Ámbar
      default:
        return defaultColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordCardsAsync = ref.watch(wordCardsProvider);
    final userCards = wordCardsAsync.value ?? [];
    final activeThemeId = widget.story.metadata['theme_id'] as String? ?? 'parchment';
    final activeTheme = StoryBackgroundWidget.themes.firstWhere(
      (t) => t.id == activeThemeId,
      orElse: () => StoryBackgroundWidget.themes.first,
    );

    return StoryBackgroundWidget(
      themeId: activeThemeId,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: activeTheme.iconColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.story.title.toUpperCase(),
            style: TextStyle(
              color: activeTheme.primaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Inter',
              letterSpacing: 1.0,
            ),
          ),
          centerTitle: true,
          actions: [
            // Botón para activar/desactivar coloreado gramatical
            IconButton(
              icon: Icon(
                _isGrammarHighlightEnabled ? Icons.palette_rounded : Icons.palette_outlined,
                color: _isGrammarHighlightEnabled ? activeTheme.primaryTextColor : activeTheme.textColor.withValues(alpha: 0.6),
              ),
              tooltip: 'Resaltado Gramatical',
              onPressed: () {
                setState(() {
                  _isGrammarHighlightEnabled = !_isGrammarHighlightEnabled;
                });
                HapticFeedback.lightImpact();
              },
            ),
            // Botón tamaño de letra
            IconButton(
              icon: Icon(Icons.text_fields_rounded, color: activeTheme.iconColor),
              onPressed: () {
                setState(() {
                  if (_fontSize >= 20.0) {
                    _fontSize = 14.0;
                  } else {
                    _fontSize += 2.0;
                  }
                });
                HapticFeedback.lightImpact();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Contenedor del texto del Relato
              Positioned.fill(
                bottom: 80, // Espacio para el panel de audio
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: _tokens.asMap().entries.map((entry) {
                      final index = entry.key;
                      final token = entry.value;

                      final isBeforeActive = _currentWordIndex != -1 && index < _currentWordIndex;
                      final isActiveHighlight = index == _currentWordIndex;

                      if (!token.isWord) {
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isBeforeActive ? 0.35 : 1.0,
                          child: Text(
                            token.text,
                            style: TextStyle(
                              fontSize: _fontSize,
                              height: 1.6,
                              fontFamily: 'Inter',
                              color: activeTheme.textColor.withValues(alpha: 0.8),
                            ),
                          ),
                        );
                      }

                      // Resolver si existe tarjeta para esta palabra
                      final cleanText = token.text.toLowerCase().trim();
                      WordCardModel? matchedCard;
                      for (final card in userCards) {
                        if (card.word.toLowerCase().trim() == cleanText) {
                          matchedCard = card;
                          break;
                        }
                      }

                      // Determinar categoría morfosintáctica
                      final category = token.category ?? matchedCard?.category;

                      // Estilo de texto coloreado por tipo gramatical
                      Color textColor = activeTheme.textColor;
                      FontWeight fontWeight = FontWeight.normal;
                      TextDecoration decoration = TextDecoration.none;

                      if (_isGrammarHighlightEnabled && category != null) {
                        textColor = _getCategoryColor(category, activeTheme.textColor);
                        fontWeight = FontWeight.bold;
                      }

                      // Si coincide con una tarjeta de vocabulario, añadir subrayado suave decorativo
                      if (matchedCard != null) {
                        decoration = TextDecoration.underline;
                      }

                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isBeforeActive ? 0.35 : 1.0,
                        child: _StoryWordWidget(
                          token: token,
                          matchedCard: matchedCard,
                          textStyle: TextStyle(
                            fontSize: _fontSize,
                            height: 1.6,
                            fontFamily: 'Inter',
                            color: isActiveHighlight 
                                ? const Color(0xFF7C3AED)
                                : (isBeforeActive ? textColor.withValues(alpha: 0.4) : textColor),
                            fontWeight: isActiveHighlight ? FontWeight.bold : fontWeight,
                            decoration: isActiveHighlight ? TextDecoration.none : decoration,
                            decorationColor: textColor.withValues(alpha: 0.5),
                            decorationStyle: TextDecorationStyle.dashed,
                          ),
                          isActiveHighlight: isActiveHighlight,
                          onTap: (word, card, wordCenter, wordSize) {
                            _showWordCard(word, card, wordCenter, wordSize);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Reproductor de Audio Flotante
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: activeTheme.isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: activeTheme.isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.border.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: activeTheme.isDark ? 0.3 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        // Badge de Dificultad
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: activeTheme.isDark
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            widget.story.difficulty,
                            style: TextStyle(
                              color: activeTheme.isDark ? const Color(0xFFA78BFA) : AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        const Spacer(),

                        // Botón Stop
                        if (_isPlaying || _currentWordIndex != -1)
                          IconButton(
                            icon: Icon(
                              Icons.stop_rounded,
                              color: activeTheme.textColor.withValues(alpha: 0.6),
                              size: 24,
                            ),
                            onPressed: _stop,
                          ),

                        // Botón Play / Pause
                        GestureDetector(
                          onTap: _speak,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: activeTheme.isDark ? const Color(0xFF8B5CF6) : const Color(0xFF0F172A),
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const Spacer(),

                        // Selector de Velocidad (TTS Speed)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              if (_speechRate == 0.5) {
                                _speechRate = 0.35; // Más lento
                              } else if (_speechRate == 0.35) {
                                _speechRate = 0.65; // Más rápido
                              } else {
                                _speechRate = 0.5; // Normal
                              }
                            });
                            if (_isPlaying) {
                              _flutterTts.setSpeechRate(_speechRate);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: activeTheme.isDark
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : AppColors.border,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _speechRate == 0.5
                                  ? '1.0x'
                                  : _speechRate == 0.35
                                      ? '0.7x'
                                      : '1.3x',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                                color: activeTheme.textColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoryToken {
  final String text;
  final String? category;
  final bool isWord;
  final int startOffset;
  final int endOffset;

  StoryToken({
    required this.text,
    this.category,
    required this.isWord,
    required this.startOffset,
    required this.endOffset,
  });
}

class _StoryWordWidget extends StatefulWidget {
  final StoryToken token;
  final WordCardModel? matchedCard;
  final TextStyle textStyle;
  final bool isActiveHighlight;
  final Function(String word, WordCardModel? card, Offset center, Size size) onTap;

  const _StoryWordWidget({
    required this.token,
    this.matchedCard,
    required this.textStyle,
    required this.isActiveHighlight,
    required this.onTap,
  });

  @override
  State<_StoryWordWidget> createState() => _StoryWordWidgetState();
}

class _StoryWordWidgetState extends State<_StoryWordWidget> {
  bool _isPressed = false;

  @override
  void didUpdateWidget(covariant _StoryWordWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll para mantener la palabra activa visible (Estilo Karaoke)
    if (widget.isActiveHighlight && !oldWidget.isActiveHighlight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            alignment: 0.5, // Centra el widget verticalmente en el viewport
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        final RenderBox box = context.findRenderObject() as RenderBox;
        final Offset globalPosition = box.localToGlobal(Offset.zero);
        final Offset centerPosition = Offset(
          globalPosition.dx + box.size.width / 2,
          globalPosition.dy,
        );
        widget.onTap(widget.token.text, widget.matchedCard, centerPosition, box.size);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: widget.isActiveHighlight
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5)
            : const EdgeInsets.symmetric(horizontal: 1.5, vertical: 0.5),
        decoration: BoxDecoration(
          color: widget.isActiveHighlight
              ? const Color(0xFF7C3AED).withValues(alpha: 0.12) // Elegant semi-transparent purple capsule
              : _isPressed
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          widget.token.text,
          style: widget.textStyle,
        ),
      ),
    );
  }
}

class StoryExercisePopup extends StatefulWidget {
  final WordCardModel card;
  final List<WordCardModel> allCards;
  final bool isBelow;
  final double arrowLeft;
  final VoidCallback onDismiss;
  final AudioService audioService;

  const StoryExercisePopup({
    super.key,
    required this.card,
    required this.allCards,
    required this.isBelow,
    required this.arrowLeft,
    required this.onDismiss,
    required this.audioService,
  });

  @override
  State<StoryExercisePopup> createState() => _StoryExercisePopupState();
}

class _StoryExercisePopupState extends State<StoryExercisePopup> {
  String _quizType = 'pregunta';
  String _quizAnswer = 'Sí';
  String _quizHiddenWord = '';
  String _exampleSentence = '';

  List<String> _wordPool = [];
  List<String> _assembledWords = [];
  List<String> _shuffledOptions = [];

  String? _selectedOption; // para completar
  int? _selectedIndex; // para pregunta/sí-no
  bool _isAnswered = false;
  bool _isCorrect = false;

  final AudioPlayer _localAudioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  void _initializeQuiz() {
    final design = widget.card.canvasDesign;
    if (design == null || design['quiz_type'] == null) {
      // Fallback si no tiene quiz configurado
      _quizType = 'pregunta';
      _exampleSentence = '¿"${widget.card.word}" significa "${widget.card.definition}"?';
      _quizAnswer = 'Sí';
    } else {
      _quizType = design['quiz_type'] as String? ?? 'pregunta';
      _quizAnswer = design['quiz_answer'] as String? ?? 'Sí';
      _quizHiddenWord = design['quiz_hidden_word'] as String? ?? '';
      _exampleSentence = widget.card.exampleSentence ?? '';
    }

    if (_quizType == 'acomodar') {
      final cleanSentence = _exampleSentence
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
    } else if (_quizType == 'completar') {
      final List<dynamic> distractorsRaw = design?['quiz_distractors'] as List<dynamic>? ?? [];
      final distractors = distractorsRaw.map((e) => e.toString()).toList();
      _shuffledOptions = [_quizHiddenWord, ...distractors]
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()..shuffle();
      _selectedOption = null;
    }
    _selectedIndex = null;
    _isAnswered = false;
    _isCorrect = false;
  }

  Future<void> _playExampleAudio() async {
    if (_isPlayingAudio) {
      await _localAudioPlayer.stop();
      setState(() {
        _isPlayingAudio = false;
      });
      return;
    }

    final url = widget.card.audioUrl;
    if (url != null && url.isNotEmpty) {
      try {
        setState(() {
          _isPlayingAudio = true;
        });
        await _localAudioPlayer.play(UrlSource(url));
        _localAudioPlayer.onPlayerComplete.first.then((_) {
          if (mounted) {
            setState(() {
              _isPlayingAudio = false;
            });
          }
        });
      } catch (e) {
        debugPrint('Error playing card audio: $e');
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
          });
        }
      }
    } else {
      final tts = FlutterTts();
      await tts.setLanguage(widget.card.language ?? 'en-US');
      await tts.speak(_exampleSentence);
    }
  }

  String _getCompletarText(String originalText, String hiddenWord) {
    if (originalText.isEmpty || hiddenWord.isEmpty) return originalText;
    final regExp = RegExp(RegExp.escape(hiddenWord), caseSensitive: false);
    return originalText.replaceAll(regExp, '_____');
  }

  bool _checkAcomodarCorrect() {
    final cleanSentence = _exampleSentence;
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

  void _checkAcomodarState() {
    final cleanSentence = _exampleSentence;
    final expectedWords = cleanSentence
        .replaceAll(RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()?¿¡]'), '')
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    if (_assembledWords.length == expectedWords.length) {
      final correct = _checkAcomodarCorrect();
      setState(() {
        _isAnswered = true;
        _isCorrect = correct;
      });

      if (correct) {
        widget.audioService.playFlip(); // Exito
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) {
            widget.onDismiss();
          }
        });
      } else {
        widget.audioService.playTap(); // Fallo
        HapticFeedback.vibrate();
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) {
            setState(() {
              _initializeQuiz();
            });
          }
        });
      }
    }
  }

  void _onOptionSelected(bool isCorrect) {
    if (isCorrect) {
      widget.audioService.playFlip();
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) {
          widget.onDismiss();
        }
      });
    } else {
      widget.audioService.playTap();
      HapticFeedback.vibrate();
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) {
          setState(() {
            _initializeQuiz();
          });
        }
      });
    }
  }

  void _onPreguntaSelected(int index) {
    if (_isAnswered) return;
    
    final isCorrect = (index == 0 && _quizAnswer == 'Sí') || (index == 1 && _quizAnswer == 'No');
    setState(() {
      _selectedIndex = index;
      _isAnswered = true;
      _isCorrect = isCorrect;
    });

    _onOptionSelected(isCorrect);
  }

  @override
  void dispose() {
    _localAudioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget rightColumnContent;
    if (_quizType == 'acomodar') {
      rightColumnContent = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ordena la frase:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              GestureDetector(
                onTap: _playExampleAudio,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlayingAudio ? Icons.stop_rounded : Icons.volume_up_rounded,
                    size: 16,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _isAnswered
                  ? (_isCorrect ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2))
                  : const Color(0xFFF8FAFC),
              border: Border.all(
                color: _isAnswered
                    ? (_isCorrect ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5))
                    : const Color(0xFFE2E8F0),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _assembledWords.isEmpty
                ? const Center(
                    child: Text(
                      'Toca abajo para ordenar',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _assembledWords.map((word) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: GestureDetector(
                            onTap: () {
                              if (_isAnswered) return;
                              setState(() {
                                _assembledWords.remove(word);
                                _wordPool.add(word);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                word,
                                style: const TextStyle(fontSize: 9, color: Color(0xFF1E293B)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: _wordPool.map((word) {
                  return GestureDetector(
                    onTap: () {
                      if (_isAnswered) return;
                      setState(() {
                        _wordPool.remove(word);
                        _assembledWords.add(word);
                      });
                      _checkAcomodarState();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        word,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    } else if (_quizType == 'completar') {
      rightColumnContent = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Text(
                _getCompletarText(_exampleSentence, _quizHiddenWord),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: List.generate(_shuffledOptions.length, (index) {
              final optionText = _shuffledOptions[index];
              final isSelected = _selectedOption == optionText;
              final isCorrect = optionText.toLowerCase() == _quizHiddenWord.toLowerCase();

              Color buttonBg = const Color(0xFFF1F5F9);
              Color textCol = const Color(0xFF334155);
              Color borderCol = const Color(0xFFE2E8F0);

              if (_isAnswered) {
                if (isCorrect) {
                  buttonBg = const Color(0xFFDCFCE7);
                  textCol = const Color(0xFF15803D);
                  borderCol = const Color(0xFF86EFAC);
                } else if (isSelected) {
                  buttonBg = const Color(0xFFFEE2E2);
                  textCol = const Color(0xFFB91C1C);
                  borderCol = const Color(0xFFFCA5A5);
                }
              }

              return GestureDetector(
                onTap: () {
                  if (_isAnswered) return;
                  setState(() {
                    _selectedOption = optionText;
                    _isAnswered = true;
                    _isCorrect = isCorrect;
                  });
                  _onOptionSelected(isCorrect);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: buttonBg,
                    border: Border.all(color: borderCol, width: 1.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    optionText,
                    style: TextStyle(
                      color: textCol,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      );
    } else {
      // 'pregunta'
      rightColumnContent = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Text(
                _exampleSentence,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(2, (index) {
              final optionText = index == 0 ? 'Sí' : 'No';
              final isSelected = _selectedIndex == index;
              final isCorrect = (index == 0 && _quizAnswer == 'Sí') || (index == 1 && _quizAnswer == 'No');

              Color buttonBg = const Color(0xFFF1F5F9);
              Color textCol = const Color(0xFF334155);
              Color borderCol = const Color(0xFFE2E8F0);

              if (_isAnswered) {
                if (isCorrect) {
                  buttonBg = const Color(0xFFDCFCE7);
                  textCol = const Color(0xFF15803D);
                  borderCol = const Color(0xFF86EFAC);
                } else if (isSelected) {
                  buttonBg = const Color(0xFFFEE2E2);
                  textCol = const Color(0xFFB91C1C);
                  borderCol = const Color(0xFFFCA5A5);
                }
              }

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 4.0,
                    right: index == 1 ? 0 : 4.0,
                  ),
                  child: GestureDetector(
                    onTap: () => _onPreguntaSelected(index),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: buttonBg,
                        border: Border.all(color: borderCol, width: 1.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          optionText,
                          style: TextStyle(
                            color: textCol,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isBelow)
          Padding(
            padding: EdgeInsets.only(left: widget.arrowLeft - 6.0),
            child: CustomPaint(
              size: const Size(12, 8),
              painter: ArrowPainter(
                color: const Color(0xFF7C3AED),
                isBelow: true,
              ),
            ),
          ),
        Container(
          width: 280,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Lado Izquierdo: Imagen de la carta
              Container(
                width: 90,
                height: 140,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                  child: widget.card.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.card.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
              // Lado Derecho: Contenido del Ejercicio
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: rightColumnContent,
                ),
              ),
            ],
          ),
        ),
        if (!widget.isBelow)
          Padding(
            padding: EdgeInsets.only(left: widget.arrowLeft - 6.0),
            child: CustomPaint(
              size: const Size(12, 8),
              painter: ArrowPainter(
                color: const Color(0xFF7C3AED),
                isBelow: false,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(
          Icons.book_rounded,
          color: Color(0xFF94A3B8),
          size: 32,
        ),
      ),
    );
  }
}
