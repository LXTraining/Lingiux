import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:lingiux_app/features/vocabulary/presentation/providers/vocabulary_provider.dart';

class CreateCardFormScreen extends ConsumerStatefulWidget {
  final Uint8List imageBytes;
  final String imageName;
  const CreateCardFormScreen({
    super.key,
    required this.imageBytes,
    required this.imageName,
  });

  @override
  ConsumerState<CreateCardFormScreen> createState() => _CreateCardFormScreenState();
}class _CreateCardFormScreenState extends ConsumerState<CreateCardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _phoneticController = TextEditingController();
  final _categoryController = TextEditingController();
  final _languageController = TextEditingController();
  final _definitionController = TextEditingController();
  final _exampleController = TextEditingController();
  bool _isSaving = false;

  // Estado para la grabación y reproducción de audio
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordedAudioPath;
  int _recordDuration = 0;
  Timer? _recordTimer;
  bool _isPlayingPreview = false;

  @override
  void dispose() {
    _wordController.dispose();
    _phoneticController.dispose();
    _categoryController.dispose();
    _languageController.dispose();
    _definitionController.dispose();
    _exampleController.dispose();
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
          _recordedAudioPath = null;
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
      setState(() {
        _isRecording = false;
        _recordedAudioPath = path;
      });
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
    if (_recordedAudioPath != null) {
      try {
        final file = File(_recordedAudioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    setState(() {
      _recordedAudioPath = null;
      _recordDuration = 0;
    });
  }

  Future<void> _togglePlayPreview() async {
    if (_recordedAudioPath == null) return;

    if (_isPlayingPreview) {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingPreview = false;
      });
    } else {
      await _audioPlayer.play(DeviceFileSource(_recordedAudioPath!));
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
  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      
      // 1. Subir la imagen a Supabase Storage como binario
      final ext = widget.imageName.contains('.') ? widget.imageName.split('.').last : 'jpg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'uploads/$fileName';

      await supabase.storage.from('word-images').uploadBinary(
        storagePath,
        widget.imageBytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      // 2. Obtener URL pública
      final imageUrl = supabase.storage.from('word-images').getPublicUrl(storagePath);

      // Subir el audio si existe grabación
      String? audioUrl;
      if (_recordedAudioPath != null) {
        final audioFile = File(_recordedAudioPath!);
        if (await audioFile.exists()) {
          final audioBytes = await audioFile.readAsBytes();
          final audioFileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
          final audioStoragePath = 'audios/$audioFileName';

          await supabase.storage.from('word-images').uploadBinary(
            audioStoragePath,
            audioBytes,
            fileOptions: const FileOptions(contentType: 'audio/m4a', upsert: false),
          );

          audioUrl = supabase.storage.from('word-images').getPublicUrl(audioStoragePath);
        }
      }

      // 3. Guardar la metadata en la tabla word_cards de Supabase
      await supabase.from('word_cards').insert({
        'user_id': supabase.auth.currentUser?.id,
        'word': _wordController.text.trim(),
        'phonetic': _phoneticController.text.trim(),
        'definition': _definitionController.text.trim(),
        'image_url': imageUrl,
        'category': _categoryController.text.trim(),
        'language': _languageController.text.trim(),
        'example_sentence': _exampleController.text.trim(),
        'audio_url': audioUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
      // 4. Invalidar el provider de Riverpod para refrescar las listas
      ref.invalidate(wordCardsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Tarjeta creada exitosamente!'),
            backgroundColor: AppColors.online,
          ),
        );
        // Retornar al feed/crear
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar tarjeta: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          // Degradado superior premium
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.gradientBgStart.withValues(alpha: 0.45),
                    AppColors.gradientBgEnd.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Nueva Tarjeta'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Stack(
              children: [
                GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Preview de la imagen
                          Center(
                            child: Container(
                              height: 160,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(
                                  widget.imageBytes,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Palabra clave
                          TextFormField(
                            controller: _wordController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Palabra Clave *',
                              hintText: 'Ej: Serendipity, Effervescent...',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Por favor ingresa la palabra.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Pronunciación Fonética
                          TextFormField(
                            controller: _phoneticController,
                            decoration: const InputDecoration(
                              labelText: 'Pronunciación Fonética *',
                              hintText: 'Ej: /ˌserənˈdipədē/',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Por favor ingresa la pronunciación.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Fila de Categoría e Idioma
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _categoryController,
                                  decoration: const InputDecoration(
                                    labelText: 'Categoría',
                                    hintText: 'Ej: Adjetivo',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _languageController,
                                  decoration: const InputDecoration(
                                    labelText: 'Idioma',
                                    hintText: 'Ej: Inglés',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Definición
                          TextFormField(
                            controller: _definitionController,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Definición *',
                              hintText: 'Escribe el significado de la palabra...',
                              alignLabelWithHint: true,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Por favor ingresa la definición.';
                              }
                              return null;
                            },
                          ),
                           const SizedBox(height: 16),
                          // Frase de Ejemplo
                          TextFormField(
                            controller: _exampleController,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Frase de Ejemplo',
                              hintText: 'Ej: Finding a ten-dollar bill was a serendipity.',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Grabación de audio
                          _buildAudioRecorderSection(),
                          const SizedBox(height: 32),
                           GestureDetector(
                            onTap: _isSaving ? null : _saveCard,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF815BF5), Color(0xFF5A45FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF815BF5).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Subir Tarjeta',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isSaving)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.2),
                      child: const Center(
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 16),
                                Text(
                                  'Subiendo tarjeta a Supabase...',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildAudioRecorderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mic_rounded,
                color: _isRecording ? AppColors.error : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Nota de voz de la carta',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isRecording && _recordedAudioPath == null) ...[
            const Text(
              'Graba un audio pronunciando o explicando el significado (máx. 15s).',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _startRecording,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_none_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Iniciar Grabación',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_isRecording) ...[
            Row(
              children: [
                _buildRecordingIndicator(),
                const SizedBox(width: 12),
                Text(
                  '0:${_recordDuration.toString().padLeft(2, '0')} / 0:15',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _stopRecording,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.stop_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_recordedAudioPath != null) ...[
            Row(
              children: [
                GestureDetector(
                  onTap: _togglePlayPreview,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlayingPreview ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio grabado con éxito',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Pulsa play para escuchar',
                      style: TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: _deleteRecording,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return const SizedBox(
      width: 12,
      height: 12,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
      ),
    );
  }
}
