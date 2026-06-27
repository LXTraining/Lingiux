import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_colors.dart';

class StepWordMnemonics extends StatefulWidget {
  final Uint8List? imageBytes;
  final String? imageName;
  final ValueChanged<Map<String, dynamic>?> onImageSelected;
  final TextEditingController definitionController;
  final TextEditingController exampleController;
  final String wordText;

  // Campos gramaticales y de audio reubicados
  final String selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final TextEditingController phoneticController;
  final String? recordedAudioPath;
  final ValueChanged<String?> onAudioRecorded;

  const StepWordMnemonics({
    super.key,
    required this.imageBytes,
    required this.imageName,
    required this.onImageSelected,
    required this.definitionController,
    required this.exampleController,
    required this.wordText,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.phoneticController,
    required this.recordedAudioPath,
    required this.onAudioRecorded,
  });

  @override
  State<StepWordMnemonics> createState() => _StepWordMnemonicsState();
}

class _StepWordMnemonicsState extends State<StepWordMnemonics> {
  final ImagePicker _picker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  bool _isPlayingPreview = false;

  // Lista de categorías gramaticales soportadas
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
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    super.dispose();
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
        widget.onAudioRecorded(null);

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
      setState(() {
        _isRecording = false;
      });
      widget.onAudioRecorded(path);
    } catch (e) {
      debugPrint('Error al detener grabación: $e');
    }
  }

  Future<void> _deleteRecording() async {
    if (_isPlayingPreview) {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingPreview = false;
      });
    }
    widget.onAudioRecorded(null);
    setState(() {
      _recordDuration = 0;
    });
  }

  Future<void> _togglePlayPreview() async {
    if (widget.recordedAudioPath == null) return;

    if (_isPlayingPreview) {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingPreview = false;
      });
    } else {
      await _audioPlayer.play(DeviceFileSource(widget.recordedAudioPath!));
      setState(() {
        _isPlayingPreview = true;
      });
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlayingPreview = false;
          });
        }
      });
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Detalles Semánticos y Nemotecnia',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Completa los datos gramaticales de la palabra y asocia una imagen con su definición.',
            style: TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // 1. Campo: Categoría
          const Text(
            'Categoría',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: widget.selectedCategory,
            onChanged: widget.onCategoryChanged,
            items: _categories.map((cat) {
              return DropdownMenuItem<String>(
                value: cat,
                child: Text(cat, style: const TextStyle(fontSize: 14, fontFamily: 'Inter')),
              );
            }).toList(),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2. Campo: Fonética
          const Text(
            'Pronunciación Fonética',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.phoneticController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'Inter',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 3. Campo: Grabadora de Voz
          const Text(
            'Pronunciación en Audio',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                if (widget.recordedAudioPath == null) ...[
                  // Estado: No grabado
                  GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? AppColors.error.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: _isRecording ? AppColors.error : AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _isRecording
                          ? 'Grabando... (${_formatDuration(_recordDuration)} / 0:15)'
                          : 'Toca el micrófono para grabar pronunciación',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Inter',
                        color: _isRecording ? AppColors.error : AppColors.onSurfaceMuted,
                        fontWeight: _isRecording ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ] else ...[
                  // Estado: Audio grabado y listo
                  GestureDetector(
                    onTap: _togglePlayPreview,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        _isPlayingPreview ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Audio de pronunciación grabado',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Inter',
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _deleteRecording,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error.withValues(alpha: 0.1),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Lienzo de la Carta Interactiva (Selector de Imagen)
          const Text(
            'Imagen de Apoyo',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 190,
                height: 270,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fondo de Imagen si ya fue seleccionada
                      if (widget.imageBytes != null) ...[
                        Image.memory(
                          widget.imageBytes!,
                          fit: BoxFit.cover,
                        ),
                        // Gradiente de contraste inferior para textos
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.75),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        // Previsualización rápida de la palabra en la parte inferior
                        Positioned(
                          bottom: 20,
                          left: 16,
                          right: 16,
                          child: Text(
                            widget.wordText.isNotEmpty ? widget.wordText : 'Palabra',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ] else ...[
                        // Estado Vacío (Borde punteado personalizado)
                        CustomPaint(
                          painter: DashedRectPainter(color: AppColors.primary.withValues(alpha: 0.4)),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_rounded,
                                size: 36,
                                color: AppColors.primary,
                              ),
                              SizedBox(height: 12),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  'Añadir Imagen',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 5. Campo: Definición o Traducción
          const Text(
            'Definición o Traducción *',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.definitionController,
            textInputAction: TextInputAction.next,
            maxLines: 2,
            style: const TextStyle(fontSize: 15, fontFamily: 'Inter'),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 6. Campo: Frase de ejemplo
          const Text(
            'Frase de Ejemplo',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.exampleController,
            textInputAction: TextInputAction.done,
            maxLines: 2,
            style: const TextStyle(fontSize: 15, fontFamily: 'Inter'),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Pintor de bordes discontinuos (Dashed) nativo para evitar dependencias
class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(24),
    );
    path.addRRect(rrect);

    final dashPath = Path();
    double distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + gap),
          Offset.zero,
        );
        distance += gap * 2;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedRectPainter oldDelegate) => oldDelegate.color != color;
}
