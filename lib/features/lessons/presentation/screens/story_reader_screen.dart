import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../vocabulary/domain/models/word_card_model.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../../../vocabulary/presentation/screens/word_detail_screen.dart';
import '../../../chat/presentation/screens/chat_detail_screen.dart';
import '../../domain/models/story_model.dart';

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

    ref.read(audioServiceProvider).playTap();
    HapticFeedback.lightImpact();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    const cardWidth = 96.0;
    const cardHeight = 136.0;

    double left = wordCenter.dx - (cardWidth / 2);
    left = left.clamp(16.0, screenWidth - cardWidth - 16.0);

    bool isBelow = true;
    double top = wordCenter.dy + wordSize.height + 8.0;

    if (top + cardHeight > screenHeight - 100) {
      isBelow = false;
      top = wordCenter.dy - cardHeight - 8.0;
    }

    final arrowLeft = (wordCenter.dx - left).clamp(16.0, cardWidth - 16.0);
    final cardController = FlippableCardController();

    void navigateToDetail() {
      _dismissOverlay();
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => WordDetailScreen(
            selectedWord: cleanWord,
            cardId: selectedWordCard?.id,
            conversationId: null,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
    }

    _overlayEntry = OverlayEntry(
      builder: (_) => OverlayEntrance(
        left: left,
        top: top,
        isBelow: isBelow,
        onDismiss: _dismissOverlay,
        onShare: () {},
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 200) {
            final swipeRight = details.primaryVelocity! > 0;
            cardController.flip(swipeRight: swipeRight);
            HapticFeedback.selectionClick();
          }
        },
        child: SizedBox(
          width: cardWidth,
          height: cardHeight + 8.0,
          child: FlippableCard(
            controller: cardController,
            isBelow: isBelow,
            arrowLeft: arrowLeft,
            front: WordMiniCardFront(
              word: cleanWord,
              card: selectedWordCard,
              onTap: navigateToDetail,
            ),
            back: WordMiniCardBack(
              word: cleanWord,
              card: selectedWordCard,
              onTap: navigateToDetail,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'VERBO':
        return const Color(0xFFEF4444); // Rojo coral
      case 'SUSTANTIVO':
        return const Color(0xFF10B981); // Verde esmeralda
      case 'ADJETIVO':
        return const Color(0xFF3B82F6); // Azul
      case 'ADVERBIO':
        return const Color(0xFFF59E0B); // Ámbar
      default:
        return AppColors.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordCardsAsync = ref.watch(wordCardsProvider);
    final userCards = wordCardsAsync.value ?? [];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFDFBF7), // Warm parchment cream
            Color(0xFFF5EDE0), // Soft sepia beige
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.onSurface, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.story.title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
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
                color: _isGrammarHighlightEnabled ? AppColors.primary : AppColors.onSurfaceMuted,
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
              icon: const Icon(Icons.text_fields_rounded, color: AppColors.onSurface),
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
              // Blob decorativo superior derecho (Melón suave)
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEADCC9).withValues(alpha: 0.35),
                  ),
                ),
              ),
              // Blob decorativo inferior izquierdo (Lavanda de la marca)
              Positioned(
                bottom: 40,
                left: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFDCD3FF).withValues(alpha: 0.25),
                  ),
                ),
              ),
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
                            color: AppColors.onSurface.withValues(alpha: 0.8),
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
                    Color textColor = AppColors.onSurface;
                    FontWeight fontWeight = FontWeight.normal;
                    TextDecoration decoration = TextDecoration.none;

                    if (_isGrammarHighlightEnabled && category != null) {
                      textColor = _getCategoryColor(category);
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
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.8), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
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
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          widget.story.difficulty,
                          style: const TextStyle(
                            color: AppColors.primary,
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
                          icon: const Icon(Icons.stop_rounded, color: AppColors.onSurfaceMuted, size: 24),
                          onPressed: _stop,
                        ),

                      // Botón Play / Pause
                      GestureDetector(
                        onTap: _speak,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF0F172A),
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
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _speechRate == 0.5
                                ? '1.0x'
                                : _speechRate == 0.35
                                    ? '0.7x'
                                    : '1.3x',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                              color: AppColors.onSurface,
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
