import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_colors.dart';

class KeywordHighlightingController extends TextEditingController {
  String _keyword;

  KeywordHighlightingController({super.text, required String keyword}) : _keyword = keyword;

  String get keyword => _keyword;
  set keyword(String value) {
    if (_keyword != value) {
      _keyword = value;
      notifyListeners();
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textVal = text;
    if (textVal.isEmpty || _keyword.isEmpty) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }

    final lowerText = textVal.toLowerCase();
    final lowerKeyword = _keyword.toLowerCase();
    final index = lowerText.indexOf(lowerKeyword);

    if (index == -1) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }

    final before = textVal.substring(0, index);
    final match = textVal.substring(index, index + _keyword.length);
    final after = textVal.substring(index + _keyword.length);

    return TextSpan(
      style: style,
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
    );
  }
}

class CardEditorWidget extends StatefulWidget {
  final TextEditingController wordController;
  final TextEditingController definitionController;
  final TextEditingController phoneticController;
  final TextEditingController exampleController;
  final TextEditingController descriptionController;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final String selectedLanguage;
  final Uint8List? imageBytes;
  final String? imageName;
  final ValueChanged<Map<String, dynamic>?> onImageSelected;
  final String? recordedAudioPath;
  final ValueChanged<String?> onAudioRecorded;
  final int selectedGradientIndex;
  final ValueChanged<int> onGradientChanged;
  final String selectedFrameType;
  final ValueChanged<String> onFrameChanged;
  final VoidCallback onBack;
  final Function(Map<String, dynamic>) onSave;
  final bool isSaving;

  const CardEditorWidget({
    super.key,
    required this.wordController,
    required this.definitionController,
    required this.phoneticController,
    required this.exampleController,
    required this.descriptionController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.selectedLanguage,
    required this.imageBytes,
    required this.imageName,
    required this.onImageSelected,
    required this.recordedAudioPath,
    required this.onAudioRecorded,
    required this.selectedGradientIndex,
    required this.onGradientChanged,
    required this.selectedFrameType,
    required this.onFrameChanged,
    required this.onBack,
    required this.onSave,
    required this.isSaving,
  });

  @override
  State<CardEditorWidget> createState() => _CardEditorWidgetState();
}

class _CardEditorWidgetState extends State<CardEditorWidget> {
  int _activeTab = 0; // 0 = Contenido, 1 = Multimedia, 2 = Estilo, 3 = Quiz
  bool _isPanelOpen = false; // El panel inicia cerrado para ver la carta grande
  String _quizType = 'pregunta'; // 'pregunta' | 'acomodar' | 'completar'
  String _quizAnswer = 'Sí'; // Para pregunta
  String _quizHiddenWord = ''; // Para completar
  final List<String> _quizDistractors = [];
  final TextEditingController _newDistractorController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  bool _isPlayingAudio = false;

  final FocusNode _exampleFocusNode = FocusNode();

  static const List<List<Color>> _gradients = [
    [Color(0xFF6366F1), Color(0xFF3B82F6)], // Indigo-Blue
    [Color(0xFF8B5CF6), Color(0xFFEC4899)], // Purple-Pink
    [Color(0xFF10B981), Color(0xFF059669)], // Emerald
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Amber
    [Color(0xFFF43F5E), Color(0xFFEF4444)], // Rose-Red
    [Color(0xFF14B8A6), Color(0xFF0D9488)], // Teal
  ];

  static const Map<String, String> _languageFlags = {
    'Inglés': 'assets/flags/us.svg',
    'Español': 'assets/flags/mx.svg',
    'Portugués': 'assets/flags/br.svg',
    'Francés': 'assets/flags/fr.svg',
    'Italiano': 'assets/flags/it.svg',
    'Alemán': 'assets/flags/de.svg',
  };

  static const List<String> _categories = [
    'Sustantivo',
    'Verbo',
    'Adjetivo',
    'Frase',
    'Adverbio',
    'Preposición',
    'Verbo Frasal',
  ];

  @override
  void initState() {
    super.initState();
    widget.wordController.addListener(_onTextChanged);
    widget.definitionController.addListener(_onTextChanged);
    widget.phoneticController.addListener(_onTextChanged);
    widget.exampleController.addListener(_onTextChanged);
    _exampleFocusNode.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.wordController.removeListener(_onTextChanged);
    widget.definitionController.removeListener(_onTextChanged);
    widget.phoneticController.removeListener(_onTextChanged);
    widget.exampleController.removeListener(_onTextChanged);
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    _exampleFocusNode.dispose();
    _newDistractorController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      widget.onImageSelected({
        'bytes': bytes,
        'name': file.name,
      });
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          setState(() {
            _recordDuration++;
          });
          if (_recordDuration >= 15) {
            await _stopRecording();
          }
        });
      }
    } catch (e) {
      debugPrint('Error al iniciar grabación: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      widget.onAudioRecorded(path);
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      debugPrint('Error al detener grabación: $e');
    }
  }

  Future<void> _deleteRecording() async {
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingAudio = false;
      });
    }
    if (widget.recordedAudioPath != null) {
      try {
        final file = File(widget.recordedAudioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    widget.onAudioRecorded(null);
    setState(() {
      _recordDuration = 0;
    });
  }

  Future<void> _playRecordedAudio() async {
    if (widget.recordedAudioPath == null) return;
    try {
      if (_isPlayingAudio) {
        await _audioPlayer.stop();
        setState(() => _isPlayingAudio = false);
      } else {
        await _audioPlayer.play(DeviceFileSource(widget.recordedAudioPath!));
        setState(() => _isPlayingAudio = true);
        _audioPlayer.onPlayerComplete.first.then((_) {
          if (mounted) {
            setState(() => _isPlayingAudio = false);
          }
        });
      }
    } catch (e) {
      debugPrint('Error al reproducir audio: $e');
    }
  }



  List<String> _getCompletarCandidates() {
    final text = widget.exampleController.text.trim();
    final keyword = widget.wordController.text.trim().toLowerCase();
    if (text.isEmpty) return [];

    final words = text
        .replaceAll(RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()?¿¡]'), '')
        .split(RegExp(r'\s+'));

    return words
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty && w.toLowerCase() != keyword)
        .toSet()
        .toList();
  }

  void _updateWordToHideOptions() {
    final candidates = _getCompletarCandidates();
    if (candidates.isNotEmpty) {
      if (_quizHiddenWord.isEmpty || !candidates.contains(_quizHiddenWord)) {
        _quizHiddenWord = candidates.first;
      }
    } else {
      _quizHiddenWord = '';
    }
  }

  String _getFirstDistractorOrPlaceholder() {
    return _quizDistractors.isNotEmpty ? _quizDistractors.first : 'Opción 2';
  }

  String _getCompletarText(String originalText, String hiddenWord) {
    if (originalText.isEmpty || hiddenWord.isEmpty) return originalText;
    final regExp = RegExp(RegExp.escape(hiddenWord), caseSensitive: false);
    return originalText.replaceAll(regExp, '_____');
  }

  Widget _buildFrameDecoration(String type, Widget child) {
    if (type == 'normal') {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
        ),
        child: child,
      );
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
            blurRadius: 8,
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
            blurRadius: 10,
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
            blurRadius: 14,
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
            blurRadius: 16,
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: frameColor, width: borderWidth),
        boxShadow: shadows,
      ),
      child: child,
    );
  }

  Widget _buildCardFront(List<Color> gradient) {
    final flagAsset = _languageFlags[widget.selectedLanguage] ?? 'assets/flags/us.svg';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo degradado
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Contenido estructurado de la tarjeta
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera: Tag y Bandera Rectangular
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.selectedCategory.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
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
                // Palabra clave (Keyword)
                Text(
                  widget.wordController.text.isNotEmpty
                      ? widget.wordController.text.toUpperCase()
                      : 'KEYWORD',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Imagen central rectangular e interactiva
                Expanded(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: widget.imageBytes != null
                            ? Image.memory(widget.imageBytes!, fit: BoxFit.cover)
                            : CustomPaint(
                                painter: DashedBorderPainter(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  borderRadius: 16,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: Colors.white.withValues(alpha: 0.6),
                                        size: 32,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Añadir Imagen',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 10,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Frase de Contexto editable directamente en la tarjeta (disimulado)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_exampleFocusNode.hasFocus || widget.exampleController.text.trim().isEmpty)
                        TextField(
                          controller: widget.exampleController,
                          focusNode: _exampleFocusNode,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontFamily: 'Inter',
                          ),
                          decoration: InputDecoration(
                            filled: false,
                            fillColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Escribe una frase de ejemplo',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                        )
                      else
                        GestureDetector(
                          onTap: () {
                            _exampleFocusNode.requestFocus();
                          },
                          child: Text(
                            _quizType == 'completar' && _quizHiddenWord.isNotEmpty
                                ? _getCompletarText(widget.exampleController.text.trim(), _quizHiddenWord)
                                : widget.exampleController.text.trim(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      if (_quizType == 'acomodar') ...[
                        const SizedBox(height: 6),
                        Text(
                          '(Acomodar: Se escuchará por audio)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ] else if (_quizType == 'completar' && _quizHiddenWord.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '(Completar: Se ocultará "$_quizHiddenWord")',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (widget.exampleController.text.isNotEmpty &&
                          !widget.exampleController.text.toLowerCase().contains(widget.wordController.text.trim().toLowerCase())) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 12),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Debe incluir la palabra "${widget.wordController.text.trim()}"',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Audio / Grabación de Frase
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (widget.recordedAudioPath != null) {
                            _playRecordedAudio();
                          } else {
                            if (_isRecording) {
                              _stopRecording();
                            } else {
                              _startRecording();
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? Colors.red.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecording ? Colors.white : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            widget.recordedAudioPath != null
                                ? (_isPlayingAudio ? Icons.stop_rounded : Icons.play_arrow_rounded)
                                : (_isRecording ? Icons.stop_rounded : Icons.mic_rounded),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      if (widget.recordedAudioPath != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _deleteRecording,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Quiz
                if (_quizType == 'pregunta') ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuizButton('Sí', _quizAnswer == 'Sí'),
                      _buildQuizButton('No', _quizAnswer == 'No'),
                    ],
                  ),
                ] else if (_quizType == 'acomodar') ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Acomodar Palabras',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else if (_quizType == 'completar') ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuizButton(_quizHiddenWord.isNotEmpty ? _quizHiddenWord : 'Opción 1', true),
                      _buildQuizButton(_getFirstDistractorOrPlaceholder(), false),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizButton(String label, bool isCorrect) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isCorrect ? 0.35 : 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: isCorrect ? 0.5 : 0.2),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[widget.selectedGradientIndex % _gradients.length];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: widget.onBack,
        ),
        title: const Text(
          'Editor de Tarjeta',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. AREA DE PREVISUALIZACIÓN CENTRAL (Ocupa más espacio en pantalla)
          Expanded(
            flex: 10,
            child: Center(
              child: SizedBox(
                width: 240,
                height: 330,
                child: _buildFrameDecoration(
                  widget.selectedFrameType,
                  _buildCardFront(gradient),
                ),
              ),
            ),
          ),

          // 2. PANEL DE EDICIÓN CONTEXTUAL (Colapsable)
          if (_isPanelOpen)
            Expanded(
              flex: 7,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: _buildActiveEditPanel(),
                  ),
                ),
              ),
            ),

          // 3. BARRA DE CONTROL INFERIOR
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 20),
            child: Row(
              children: [
                // Fila de 4 Pestañas
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTabButton(0, Icons.description_outlined, 'Contenido'),
                      _buildTabButton(1, Icons.perm_media_outlined, 'Media'),
                      _buildTabButton(2, Icons.palette_outlined, 'Estilo'),
                      _buildTabButton(3, Icons.quiz_outlined, 'Quiz'),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Botón de Guardar Circular Flotante
                GestureDetector(
                  onTap: widget.isSaving ? null : _onSavePressed,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isSaving ? AppColors.onSurfaceMuted : Colors.black,
                      boxShadow: [
                        if (!widget.isSaving)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Center(
                      child: widget.isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isActive = _activeTab == index && _isPanelOpen;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_activeTab == index) {
            _isPanelOpen = !_isPanelOpen;
          } else {
            _activeTab = index;
            _isPanelOpen = true;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : AppColors.onSurfaceMuted,
              size: 20,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.onSurfaceMuted,
                fontSize: 9,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveEditPanel() {
    switch (_activeTab) {
      case 0:
        return _buildContentPanel();
      case 1:
        return _buildMediaPanel();
      case 2:
        return _buildStylePanel();
      case 3:
        return _buildQuizPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildContentPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Texto y Significado',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
        const SizedBox(height: 12),
        // Definición
        TextField(
          controller: widget.definitionController,
          decoration: const InputDecoration(
            labelText: 'Definición / Traducción',
            hintText: 'Ej: Amistoso o ingenioso',
          ),
        ),

        const SizedBox(height: 12),
        // Pronunciación
        TextField(
          controller: widget.phoneticController,
          decoration: const InputDecoration(
            labelText: 'Pronunciación (Fonética)',
            hintText: 'Ej: /klév-er/',
          ),
        ),
        const SizedBox(height: 16),
        // Categoría Gramatical Chips
        const Text(
          'Categoría Gramatical',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final isSelected = widget.selectedCategory == cat;
            return ChoiceChip(
              label: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.onSurface,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.black,
              backgroundColor: AppColors.border.withValues(alpha: 0.2),
              onSelected: (bool selected) {
                if (selected) {
                  widget.onCategoryChanged(cat);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: widget.descriptionController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Descripción de la carta / Explicación',
            hintText: 'Ej: Los perros nunca son de pelaje azul...',
            helperText: 'Aparecerá como explicación tras resolver el ejercicio.',
          ),
        ),
      ],
    );
  }

  Widget _buildMediaPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Multimedia de Apoyo',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
        const SizedBox(height: 16),
        // Sección Imagen
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_search_rounded, size: 18),
                label: Text(widget.imageBytes != null ? 'Cambiar Imagen' : 'Subir Imagen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (widget.imageBytes != null) ...[
              const SizedBox(width: 10),
              IconButton(
                onPressed: () {
                  widget.onImageSelected(null);
                  setState(() {});
                },
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        const Divider(height: 1, thickness: 0.5),
        const SizedBox(height: 20),
        // Sección Audio
        const Text(
          'Grabación de Voz',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
        const SizedBox(height: 10),
        if (widget.recordedAudioPath == null && !_isRecording)
          ElevatedButton.icon(
            onPressed: _startRecording,
            icon: const Icon(Icons.mic_none_rounded, size: 18),
            label: const Text('Iniciar Grabación'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          )
        else if (_isRecording)
          Row(
            children: [
              const Icon(Icons.fiber_manual_record, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Grabando... ${_recordDuration}s / 15s',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _stopRecording,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Detener'),
              ),
            ],
          )
        else if (widget.recordedAudioPath != null)
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _playRecordedAudio,
                icon: Icon(_isPlayingAudio ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(_isPlayingAudio ? 'Parar' : 'Probar Audio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.online,
                  foregroundColor: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _deleteRecording,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStylePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estilo de Tarjeta',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
        const SizedBox(height: 14),
        // 1. Selector de Gradiente
        const Text(
          'Color de Fondo',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _gradients.length,
            itemBuilder: (context, index) {
              final isSelected = widget.selectedGradientIndex == index;
              final colors = _gradients[index];

              return GestureDetector(
                onTap: () => widget.onGradientChanged(index),
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors[0].withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Center(
                          child: Icon(Icons.check, color: Colors.white, size: 20),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        // 2. Selector de Marcos
        const Text(
          'Tipo de Marco (Dificultad/Hito)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['normal', 'bronce', 'plata', 'oro', 'neon'].map((type) {
            final isSelected = widget.selectedFrameType == type;
            return ChoiceChip(
              label: Text(
                type.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.black,
              backgroundColor: AppColors.border.withValues(alpha: 0.2),
              onSelected: (bool selected) {
                if (selected) {
                  widget.onFrameChanged(type);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _onSavePressed() {
    final exampleText = widget.exampleController.text.trim();
    final keyword = widget.wordController.text.trim();

    if (exampleText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, escribe una frase de ejemplo.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!exampleText.toLowerCase().contains(keyword.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La frase de ejemplo debe incluir la palabra clave "$keyword".'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_quizType == 'pregunta') {
      if (!exampleText.endsWith('?')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Para el ejercicio "Pregunta", la frase debe terminar con "?".'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    } else if (_quizType == 'acomodar') {
      if (widget.recordedAudioPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Para el ejercicio "Acomodar", es obligatorio grabar la voz.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    } else if (_quizType == 'completar') {
      final candidates = _getCompletarCandidates();
      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La frase de ejemplo no tiene palabras suficientes para ocultar.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (_quizDistractors.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Para el ejercicio "Completar", debes ingresar al menos 2 distractores.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    final quizConfig = {
      'quiz_type': _quizType,
      'quiz_answer': _quizAnswer,
      'quiz_hidden_word': _quizHiddenWord,
      'quiz_distractors': _quizDistractors,
      'description': widget.descriptionController.text.trim(),
    };

    widget.onSave(quizConfig);
  }

  Widget _buildQuizPanel() {
    final hasAudio = widget.recordedAudioPath != null;
    final hasSentence = widget.exampleController.text.trim().isNotEmpty;

    final isPreguntaEnabled = hasSentence;
    final isAcomodarEnabled = hasSentence && hasAudio;
    final isCompletarEnabled = _getCompletarCandidates().isNotEmpty;

    // Fallback if the current selection becomes invalid
    if (_quizType == 'acomodar' && !isAcomodarEnabled) {
      _quizType = 'pregunta';
    } else if (_quizType == 'completar' && !isCompletarEnabled) {
      _quizType = 'pregunta';
    } else if (_quizType == 'pregunta' && !isPreguntaEnabled) {
      // keep it but it will be locked
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configurar Ejercicio de Quiz',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildSquareTypeButton(
              type: 'pregunta',
              label: 'Pregunta',
              icon: Icons.help_outline_rounded,
              isEnabled: isPreguntaEnabled,
            ),
            _buildSquareTypeButton(
              type: 'acomodar',
              label: 'Acomodar',
              icon: Icons.sort_rounded,
              isEnabled: isAcomodarEnabled,
            ),
            _buildSquareTypeButton(
              type: 'completar',
              label: 'Completar',
              icon: Icons.space_bar_rounded,
              isEnabled: isCompletarEnabled,
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_quizType == 'pregunta') _buildPreguntaConfig(),
        if (_quizType == 'acomodar') _buildAcomodarConfig(),
        if (_quizType == 'completar') _buildCompletarConfig(),
      ],
    );
  }

  Widget _buildSquareTypeButton({
    required String type,
    required String label,
    required IconData icon,
    required bool isEnabled,
  }) {
    final isSelected = _quizType == type;

    Color backgroundColor = Colors.transparent;
    Color borderColor = AppColors.border.withValues(alpha: 0.15);
    Color contentColor = AppColors.onSurface.withValues(alpha: 0.5);

    if (isSelected && isEnabled) {
      backgroundColor = Colors.black;
      borderColor = Colors.black;
      contentColor = Colors.white;
    } else if (!isEnabled) {
      backgroundColor = AppColors.border.withValues(alpha: 0.05);
      borderColor = AppColors.border.withValues(alpha: 0.05);
      contentColor = AppColors.onSurface.withValues(alpha: 0.25);
    } else {
      backgroundColor = AppColors.border.withValues(alpha: 0.1);
      borderColor = AppColors.border.withValues(alpha: 0.2);
      contentColor = AppColors.onSurface;
    }

    return Expanded(
      child: GestureDetector(
        onTap: isEnabled
            ? () {
                setState(() {
                  _quizType = type;
                  if (type == 'completar') {
                    _updateWordToHideOptions();
                  }
                });
              }
            : () {
                String reason = '';
                if (type == 'acomodar') {
                  reason = 'Requiere escribir una frase de ejemplo y grabar tu pronunciación de voz.';
                } else {
                  reason = 'Escribe primero una frase de ejemplo en la pestaña "Contenido".';
                }
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(reason),
                    backgroundColor: Colors.amber[800],
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
        child: Container(
          height: 80,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Stack(
            children: [
              if (!isEnabled)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(Icons.lock_rounded, size: 12, color: AppColors.onSurfaceMuted),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: contentColor, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: contentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreguntaConfig() {
    final hasQuestionMark = widget.exampleController.text.trim().endsWith('?');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Validación de Frase',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              hasQuestionMark ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
              color: hasQuestionMark ? Colors.green : Colors.amber,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasQuestionMark
                    ? 'La frase termina correctamente con "?"'
                    : 'Recomendado: La frase de ejemplo debe ser una pregunta (terminar con "?").',
                style: TextStyle(
                  fontSize: 11,
                  color: hasQuestionMark ? Colors.green : AppColors.onSurfaceMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          '2. Respuesta Correcta',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Sí (True)'),
              selected: _quizAnswer == 'Sí',
              onSelected: (val) {
                if (val) setState(() => _quizAnswer = 'Sí');
              },
            ),
            const SizedBox(width: 10),
            ChoiceChip(
              label: const Text('No (False)'),
              selected: _quizAnswer == 'No',
              onSelected: (val) {
                if (val) setState(() => _quizAnswer = 'No');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAcomodarConfig() {
    final hasAudio = widget.recordedAudioPath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Requisito de Audio',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              hasAudio ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
              color: hasAudio ? Colors.green : Colors.redAccent,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasAudio
                    ? 'Audio grabado disponible.'
                    : 'Obligatorio: Este ejercicio requiere grabar pronunciación de voz primero.',
                style: TextStyle(
                  fontSize: 11,
                  color: hasAudio ? Colors.green : Colors.redAccent,
                  fontWeight: hasAudio ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildDistractorPanel(),
      ],
    );
  }

  Widget _buildCompletarConfig() {
    final candidates = _getCompletarCandidates();
    if (candidates.isEmpty) {
      return const Text(
        'Escribe una frase de ejemplo con más palabras para poder ocultar una.',
        style: TextStyle(fontSize: 11, color: Colors.redAccent),
      );
    }

    if (_quizHiddenWord.isEmpty || !candidates.contains(_quizHiddenWord)) {
      _quizHiddenWord = candidates.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Palabra a Ocultar',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _quizHiddenWord,
          items: candidates.map((word) {
            return DropdownMenuItem<String>(
              value: word,
              child: Text(word),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _quizHiddenWord = val);
            }
          },
          decoration: const InputDecoration(
            labelText: 'Selecciona una palabra de la frase',
          ),
        ),
        const SizedBox(height: 20),
        _buildDistractorPanel(),
      ],
    );
  }

  Widget _buildDistractorPanel() {
    final canAdd = _quizDistractors.length < 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. Palabras Distractoras (Incorrectas)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 4),
        Text(
          'Añade entre 1 y 3 palabras incorrectas para el ejercicio. (${_quizDistractors.length}/3)',
          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 10),
        if (_quizDistractors.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quizDistractors.map((word) {
              return Chip(
                label: Text(word, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                deleteIcon: const Icon(Icons.cancel, size: 14),
                onDeleted: () {
                  setState(() {
                    _quizDistractors.remove(word);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newDistractorController,
                enabled: canAdd,
                decoration: InputDecoration(
                  labelText: canAdd ? 'Escribe una palabra' : 'Límite alcanzado (máx 3)',
                  hintText: 'Ej: house',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _addDistractor(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: canAdd ? _addDistractor : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Añadir'),
            ),
          ],
        ),
      ],
    );
  }

  void _addDistractor() {
    final text = _newDistractorController.text.trim();
    if (text.isEmpty) return;
    if (_quizDistractors.contains(text)) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esa palabra ya fue agregada como distractor.')),
      );
      return;
    }
    if (_quizDistractors.length >= 3) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Límite de 3 distractores alcanzado.')),
      );
      return;
    }
    setState(() {
      _quizDistractors.add(text);
      _newDistractorController.clear();
    });
  }
}

// Pintor personalizado para dibujar líneas punteadas
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedBorderPainter({
    this.color = Colors.white54,
    this.strokeWidth = 1.5,
    this.gap = 4.0,
    this.dashLength = 6.0,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = _buildDashedPath(path, dashLength, gap);
    canvas.drawPath(dashPath, paint);
  }

  Path _buildDashedPath(Path source, double dashLength, double gap) {
    final Path dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? dashLength : gap;
        if (distance + len > metric.length) {
          dest.addPath(
            metric.extractPath(distance, metric.length),
            Offset.zero,
          );
        } else {
          dest.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
