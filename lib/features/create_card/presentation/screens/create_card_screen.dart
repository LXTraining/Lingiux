import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../widgets/step_word_identity.dart';
import '../widgets/step_word_mnemonics.dart';
import '../widgets/step_card_aesthetics.dart';
import '../widgets/step_card_preview.dart';
import '../../../home/presentation/providers/navigation_provider.dart';

class CreateCardScreen extends ConsumerStatefulWidget {
  final bool isActive;
  const CreateCardScreen({super.key, required this.isActive});

  @override
  ConsumerState<CreateCardScreen> createState() => _CreateCardScreenState();
}

class _CreateCardScreenState extends ConsumerState<CreateCardScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // ESTADO LOCAL DE LA NUEVA TARJETA
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _phoneticController = TextEditingController();
  final TextEditingController _definitionController = TextEditingController();
  final TextEditingController _exampleController = TextEditingController();
  
  String _selectedCategory = 'Sustantivo';
  String _selectedLanguage = 'Inglés';
  String? _recordedAudioPath;
  
  Uint8List? _imageBytes;
  String? _imageName;
  
  int _selectedGradientIndex = 0;
  String _selectedFrameType = 'normal';

  @override
  void dispose() {
    _pageController.dispose();
    _wordController.dispose();
    _phoneticController.dispose();
    _definitionController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validar Paso 1: Palabra requerida
      if (_wordController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, ingresa una palabra.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    } else if (_currentStep == 1) {
      // Validar Paso 2: Definición requerida
      if (_definitionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, ingresa una definición o traducción.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _saveCard();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _saveCard() async {
    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      String? imageUrl;

      // 1. Subir la imagen si existe
      if (_imageBytes != null && _imageName != null) {
        final ext = _imageName!.contains('.') ? _imageName!.split('.').last : 'jpg';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        final storagePath = 'uploads/$fileName';

        await supabase.storage.from('word-images').uploadBinary(
          storagePath,
          _imageBytes!,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
        imageUrl = supabase.storage.from('word-images').getPublicUrl(storagePath);
      }

      // 2. Subir el audio si existe
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

      // 3. Guardar en word_cards con canvas_design
      await supabase.from('word_cards').insert({
        'user_id': supabase.auth.currentUser?.id,
        'word': _wordController.text.trim(),
        'phonetic': _phoneticController.text.trim(),
        'definition': _definitionController.text.trim(),
        'image_url': imageUrl ?? '', // URL vacía si no se subió foto
        'category': _selectedCategory.toUpperCase(),
        'language': _selectedLanguage.toUpperCase(),
        'example_sentence': _exampleController.text.trim(),
        'audio_url': audioUrl,
        'created_at': DateTime.now().toIso8601String(),
        'canvas_design': {
          'gradient_index': _selectedGradientIndex,
          'frame_type': _selectedFrameType,
        },
      });

      // 4. Invalidar proveedores Riverpod para refrescar listas
      ref.invalidate(wordCardsProvider);
      ref.invalidate(userWordCardsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Tarjeta Mental creada con éxito!'),
            backgroundColor: AppColors.online,
          ),
        );
        
        // Limpiar el formulario y reiniciar el Stepper
        _wordController.clear();
        _phoneticController.clear();
        _definitionController.clear();
        _exampleController.clear();
        setState(() {
          _currentStep = 0;
          _imageBytes = null;
          _imageName = null;
          _recordedAudioPath = null;
          _selectedGradientIndex = 0;
          _selectedFrameType = 'normal';
        });
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }

        // Redirigir a la pestaña de Inicio/Feed (Pestaña 0)
        ref.read(activeTabProvider.notifier).state = 0;
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
    // Escuchar si hay una palabra pendiente de precargar desde el chat
    ref.listen<String?>(pendingWordProvider, (previous, next) {
      if (next != null && next.trim().isNotEmpty) {
        _wordController.text = next.trim();
        // Limpiamos el estado pendiente para no ciclar
        ref.read(pendingWordProvider.notifier).state = null;
      }
    });

    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          // Fondo degradado espacial
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
            body: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // 1. BARRA DE PROGRESO DEL STEPPER (Hasta arriba y más gruesa)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getStepTitle(_currentStep),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'Inter',
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              'Paso ${_currentStep + 1} de 4',
                              style: const TextStyle(
                                color: AppColors.onSurfaceMuted,
                                fontSize: 11,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Barra de progreso lineal animada (Más gruesa)
                        Stack(
                          children: [
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.border.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: 8,
                              width: MediaQuery.of(context).size.width *
                                  0.88 *
                                  ((_currentStep + 1) / 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF815BF5), Color(0xFF5A45FF)],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. PAGEVIEW CON LOS PASOS DEL ASISTENTE
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(), // Bloquear swipe manual
                      children: [
                        StepWordIdentity(
                          wordController: _wordController,
                          selectedLanguage: _selectedLanguage,
                          onLanguageChanged: (val) {
                            if (val != null) setState(() => _selectedLanguage = val);
                          },
                        ),
                        StepWordMnemonics(
                          imageBytes: _imageBytes,
                          imageName: _imageName,
                          wordText: _wordController.text.trim(),
                          definitionController: _definitionController,
                          exampleController: _exampleController,
                          onImageSelected: (map) {
                            if (map != null) {
                              setState(() {
                                _imageBytes = map['bytes'] as Uint8List;
                                _imageName = map['name'] as String;
                              });
                            }
                          },
                          selectedCategory: _selectedCategory,
                          onCategoryChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                          phoneticController: _phoneticController,
                          recordedAudioPath: _recordedAudioPath,
                          onAudioRecorded: (val) => setState(() => _recordedAudioPath = val),
                        ),
                        StepCardAesthetics(
                          imageBytes: _imageBytes,
                          wordText: _wordController.text.trim(),
                          selectedGradientIndex: _selectedGradientIndex,
                          onGradientChanged: (index) => setState(() => _selectedGradientIndex = index),
                          selectedFrameType: _selectedFrameType,
                          onFrameChanged: (type) => setState(() => _selectedFrameType = type),
                        ),
                        StepCardPreview(
                          wordText: _wordController.text.trim(),
                          phoneticText: _phoneticController.text.trim(),
                          definitionText: _definitionController.text.trim(),
                          exampleText: _exampleController.text.trim(),
                          imageBytes: _imageBytes,
                          recordedAudioPath: _recordedAudioPath,
                          selectedGradientIndex: _selectedGradientIndex,
                          selectedFrameType: _selectedFrameType,
                        ),
                      ],
                    ),
                  ),

                // 3. BOTONERA INFERIOR (Soft UI)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    children: [
                      // Botón Atrás (Solo visible si paso > 0)
                      if (_currentStep > 0) ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: _prevStep,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.border.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Atrás',
                                  style: TextStyle(
                                    color: AppColors.onSurfaceMuted,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],

                      // Botón Continuar / Crear
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSaving ? null : _nextStep,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _isSaving ? AppColors.onSurfaceMuted : Colors.black,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                if (!_isSaving)
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Center(
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _currentStep == 3 ? 'Crear Tarjeta Mental' : 'Continuar',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
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
          ),
        ),
      ],
    ),
  );
}

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'IDENTIDAD';
      case 1:
        return 'NEMOTECNIA';
      case 2:
        return 'ESTÉTICA';
      case 3:
        return 'PREVISUALIZACIÓN';
      default:
        return '';
    }
  }
}
