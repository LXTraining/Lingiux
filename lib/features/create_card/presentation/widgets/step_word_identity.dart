import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_colors.dart';

class StepWordIdentity extends StatefulWidget {
  final TextEditingController wordController;
  final TextEditingController phoneticController;
  final String selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final String selectedLanguage;
  final ValueChanged<String?> onLanguageChanged;
  final String? recordedAudioPath;
  final ValueChanged<String?> onAudioRecorded;

  const StepWordIdentity({
    super.key,
    required this.wordController,
    required this.phoneticController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.recordedAudioPath,
    required this.onAudioRecorded,
  });

  @override
  State<StepWordIdentity> createState() => _StepWordIdentityState();
}

class _StepWordIdentityState extends State<StepWordIdentity> {
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

  // Lista de idiomas de aprendizaje comunes
  static const List<String> _languages = [
    'Inglés',
    'Alemán',
    'Francés',
    'Italiano',
    'Español',
    'Portugués',
    'Ruso',
  ];

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    super.dispose();
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
      _audioPlayer.onPlayerComplete.first.then((_) {
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
            'Identidad de la Palabra',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Comencemos registrando los detalles semánticos y de audio base para la palabra.',
            style: TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Campo: Palabra clave
          const Text(
            'Palabra *',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.wordController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
            decoration: InputDecoration(
              hintText: 'Ej. Dog, Run, Beautiful...',
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

          // Fila: Categoría e Idioma
          Row(
            children: [
              // Dropdown: Categoría
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              ),
              const SizedBox(width: 14),

              // Dropdown: Idioma
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Idioma',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: widget.selectedLanguage,
                      onChanged: widget.onLanguageChanged,
                      items: _languages.map((lang) {
                        return DropdownMenuItem<String>(
                          value: lang,
                          child: Text(lang, style: const TextStyle(fontSize: 14, fontFamily: 'Inter')),
                        );
                      }).toList(),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Campo: Fonética
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
              hintText: 'Ej. /dɒɡ/, /rʌn/, /ˈbjuːtɪfl/...',
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
          const SizedBox(height: 24),

          // Grabación de Audio (Sección Soft UI Premium)
          const Text(
            'Pronunciación en Audio',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                if (widget.recordedAudioPath == null && !_isRecording) ...[
                  // Estado inicial
                  const Icon(Icons.mic_none_rounded, size: 36, color: AppColors.onSurfaceMuted),
                  const SizedBox(height: 10),
                  const Text(
                    'Graba tu pronunciación para la tarjeta (Máx. 15s)',
                    style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _startRecording,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record, color: AppColors.error, size: 14),
                          SizedBox(width: 8),
                          Text(
                            'Grabar Audio',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (_isRecording) ...[
                  // Grabando activamente
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Grabando... ${_formatDuration(_recordDuration)}',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _stopRecording,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ] else ...[
                  // Grabación completada y guardada temporalmente
                  Row(
                    children: [
                      // Reproducir muestra
                      GestureDetector(
                        onTap: _togglePlayPreview,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlayingPreview ? Icons.stop_rounded : Icons.play_arrow_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pronunciación Grabada',
                              style: TextStyle(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Presiona para escuchar una muestra',
                              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // Eliminar grabación
                      IconButton(
                        onPressed: _deleteRecording,
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      ),
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
}
