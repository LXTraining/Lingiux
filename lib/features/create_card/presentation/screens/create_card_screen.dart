import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../widgets/step_word_identity.dart';
import '../../../home/presentation/providers/navigation_provider.dart';
import '../../../lessons/presentation/screens/create_lesson_wizard_screen.dart';
import '../../../lessons/presentation/screens/story_editor_screen.dart';
import '../../../lessons/presentation/screens/story_reader_screen.dart';
import '../../../lessons/presentation/providers/stories_provider.dart';
import '../../../lessons/domain/models/story_model.dart';
import '../widgets/card_editor_widget.dart';

class CreateCardScreen extends ConsumerStatefulWidget {
  final bool isActive;
  const CreateCardScreen({super.key, required this.isActive});

  @override
  ConsumerState<CreateCardScreen> createState() => _CreateCardScreenState();
}

class _CreateCardScreenState extends ConsumerState<CreateCardScreen> {
  int _currentStep = -1; // -1 = Selección de creación, 0 = Identidad / Validador, 1 = Editor interactivo en tiempo real
  bool _isSaving = false;

  // ESTADO LOCAL DE LA NUEVA TARJETA
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _phoneticController = TextEditingController();
  final TextEditingController _definitionController = TextEditingController();
  final TextEditingController _exampleController = KeywordHighlightingController(keyword: '');
  final TextEditingController _descriptionController = TextEditingController();
  
  String _selectedCategory = 'Sustantivo';
  String _selectedLanguage = 'Inglés';
  String? _recordedAudioPath;
  
  Uint8List? _imageBytes;
  String? _imageName;
  
  int _selectedGradientIndex = 0;
  String _selectedFrameType = 'normal';

  @override
  void initState() {
    super.initState();
    _wordController.addListener(() {
      if (_exampleController is KeywordHighlightingController) {
        _exampleController.keyword = _wordController.text.trim();
      }
    });
  }

  @override
  void dispose() {
    _wordController.dispose();
    _phoneticController.dispose();
    _definitionController.dispose();
    _exampleController.dispose();
    _descriptionController.dispose();
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
      setState(() {
        _currentStep = 1;
      });
      ref.read(isCardEditorActiveProvider.notifier).state = true;
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep = 0;
      });
      ref.read(isCardEditorActiveProvider.notifier).state = false;
    } else if (_currentStep == 0) {
      setState(() {
        _currentStep = -1;
      });
      ref.read(pendingConversationIdProvider.notifier).state = null;
    }
  }

  Future<void> _saveCard(Map<String, dynamic> quizConfig) async {
    final word = _wordController.text.trim();
    final example = _exampleController.text.trim();

    if (example.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa una frase de ejemplo.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!example.toLowerCase().contains(word.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La frase de ejemplo debe contener la palabra clave "$word".'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_isSaving) return;
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

      final conversationId = ref.read(pendingConversationIdProvider);

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
        'conversation_id': conversationId,
        'canvas_design': {
          'gradient_index': _selectedGradientIndex,
          'frame_type': _selectedFrameType,
          ...quizConfig,
        },
      });

      // Limpiar el ID de conversación pendiente
      ref.read(pendingConversationIdProvider.notifier).state = null;

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
        
        // Limpiar el formulario y reiniciar
        _wordController.clear();
        _phoneticController.clear();
        _definitionController.clear();
        _exampleController.clear();
        setState(() {
          _currentStep = -1;
          _imageBytes = null;
          _imageName = null;
          _recordedAudioPath = null;
          _selectedGradientIndex = 0;
          _selectedFrameType = 'normal';
        });
        ref.read(isCardEditorActiveProvider.notifier).state = false;

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
        setState(() {
          _currentStep = 0; // Ir directo a la creación de carta
        });
        // Limpiamos el estado pendiente para no ciclar
        ref.read(pendingWordProvider.notifier).state = null;
      }
    });

    // Escuchar si hay una conversación de chat pendiente para ir directo al creador local
    ref.listen<String?>(pendingConversationIdProvider, (previous, next) {
      if (next != null && next.trim().isNotEmpty) {
        setState(() {
          _currentStep = 0; // Ir directo a la creación de carta
        });
      }
    });

    if (_currentStep == 1) {
      return CardEditorWidget(
        wordController: _wordController,
        definitionController: _definitionController,
        phoneticController: _phoneticController,
        exampleController: _exampleController,
        descriptionController: _descriptionController,
        selectedCategory: _selectedCategory,
        onCategoryChanged: (val) => setState(() => _selectedCategory = val),
        selectedLanguage: _selectedLanguage,
        imageBytes: _imageBytes,
        imageName: _imageName,
        onImageSelected: (map) {
          if (map != null) {
            setState(() {
              _imageBytes = map['bytes'] as Uint8List;
              _imageName = map['name'] as String;
            });
          } else {
            setState(() {
              _imageBytes = null;
              _imageName = null;
            });
          }
        },
        recordedAudioPath: _recordedAudioPath,
        onAudioRecorded: (val) => setState(() => _recordedAudioPath = val),
        selectedGradientIndex: _selectedGradientIndex,
        onGradientChanged: (index) => setState(() => _selectedGradientIndex = index),
        selectedFrameType: _selectedFrameType,
        onFrameChanged: (type) => setState(() => _selectedFrameType = type),
        onBack: _prevStep,
        onSave: _saveCard,
        isSaving: _isSaving,
      );
    }

    if (_currentStep == -1) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
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
                      AppColors.gradientBgEnd.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Barra de búsqueda premium en el encabezado
                    Container(
                      height: 50,
                      clipBehavior: Clip.antiAlias, // Asegura que los bordes redondeados recorten el contenido
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: AppColors.border, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.015),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Inter',
                          color: AppColors.onSurface,
                        ),
                        decoration: InputDecoration(
                          filled: false, // Evita heredar fondos rectangulares del tema global
                          fillColor: Colors.transparent, // Fondo transparente
                          hintText: 'Buscar lecciones, cartas o relatos...',
                          hintStyle: TextStyle(
                            color: AppColors.onSurfaceMuted.withOpacity(0.8),
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.onSurfaceMuted,
                            size: 20,
                          ),
                          suffixIcon: const Icon(
                            Icons.tune_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Fila superior de recuadros horizontales distribuidos uniformemente
                    Row(
                      children: [
                        Expanded(
                          child: _buildSelectionCard(
                            context: context,
                            title: 'Carta',
                            subtitle: 'VOCABULARIO',
                            icon: Icons.auto_awesome_motion_rounded,
                            gradient: const [Color(0xFF815BF5), Color(0xFF5A45FF)],
                            onTap: () {
                              setState(() {
                                _currentStep = 0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelectionCard(
                            context: context,
                            title: 'Lección',
                            subtitle: 'CAMINOS',
                            icon: Icons.map_rounded,
                            gradient: const [Color(0xFFFF6B8B), Color(0xFFFF8E53)],
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateLessonWizardScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelectionCard(
                            context: context,
                            title: 'Relato',
                            subtitle: 'LECTURAS',
                            icon: Icons.auto_stories_rounded,
                            gradient: const [Color(0xFF4FA4F4), Color(0xFF4CD9A3)],
                            isFuture: false,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StoryEditorScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Relatos y Lecturas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                            color: AppColors.onSurface,
                          ),
                        ),
                        Icon(
                          Icons.menu_book_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ref.watch(storiesListProvider).when(
                        data: (stories) {
                          if (stories.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_stories_outlined,
                                    color: AppColors.onSurfaceMuted.withOpacity(0.4),
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No hay relatos todavía.',
                                    style: TextStyle(
                                      color: AppColors.onSurfaceMuted.withOpacity(0.8),
                                      fontSize: 13,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: stories.length,
                            itemBuilder: (context, index) {
                              final story = stories[index];
                              return _buildStoryItemCard(context, story);
                            },
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                        error: (err, stack) => Center(
                          child: Text(
                            'Error al cargar relatos: $err',
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
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

    // Step 0 - Validator Screen
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
                    AppColors.gradientBgEnd.withValues(alpha: 0.0),
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
                  // Progress Bar (Paso 1 de 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _prevStep,
                              child: const Icon(
                                Icons.arrow_back_ios_rounded,
                                color: AppColors.onSurfaceMuted,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'IDENTIDAD',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'Inter',
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              'Paso 1 de 2',
                              style: TextStyle(
                                color: AppColors.onSurfaceMuted,
                                fontSize: 11,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
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
                            Container(
                              height: 8,
                              width: MediaQuery.of(context).size.width * 0.88 * 0.5, // 50%
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
                  if (ref.watch(pendingConversationIdProvider) != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF81C784), width: 0.8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFF2E7D32),
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Nota: Esta tarjeta será privada y local para tu conversación actual.',
                                style: TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Expanded(
                    child: StepWordIdentity(
                      wordController: _wordController,
                      selectedLanguage: _selectedLanguage,
                      onLanguageChanged: (val) {
                        if (val != null) setState(() => _selectedLanguage = val);
                      },
                    ),
                  ),
                  // Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: GestureDetector(
                      onTap: _nextStep,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Continuar',
                            style: TextStyle(
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
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    bool isFuture = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        height: 125, // Altura fija para evitar desbordamientos en pantallas pequeñas
        decoration: BoxDecoration(
          color: isFuture ? Colors.white.withOpacity(0.65) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isFuture 
                ? AppColors.border.withOpacity(0.5) 
                : AppColors.border.withOpacity(0.8), 
            width: 1
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isFuture ? 0.005 : 0.012),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isFuture 
                              ? [Colors.grey.shade300, Colors.grey.shade400] 
                              : gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: isFuture
                            ? []
                            : [
                                BoxShadow(
                                  color: gradient[0].withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: Icon(
                        isFuture ? Icons.lock_outline_rounded : icon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: TextStyle(
                        color: isFuture ? AppColors.onSurfaceMuted : AppColors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.onSurfaceMuted.withOpacity(0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            if (isFuture)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PRONTO',
                    style: TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 6,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  void _showFutureFeatureSnackbar(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Próximamente! Estamos construyendo "$featureName" para la comunidad 🚀',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildStoryItemCard(BuildContext context, StoryModel story) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF4FA4F4), Color(0xFF4CD9A3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          story.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
            color: AppColors.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${story.language.toUpperCase()} • Nivel ${story.difficulty} • ${story.content.split(' ').length} palabras',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Inter',
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppColors.onSurfaceMuted,
          size: 14,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoryReaderScreen(story: story),
            ),
          );
        },
      ),
    );
  }
}
