import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../../../vocabulary/domain/models/word_card_model.dart';
import '../providers/lessons_provider.dart';
import '../../domain/models/lesson_exercise_model.dart';
import '../../domain/models/lesson_model.dart';
import '../../../../core/constants/app_colors.dart';

class CreateLessonWizardScreen extends ConsumerStatefulWidget {
  final LessonModel? lessonToEdit;
  const CreateLessonWizardScreen({super.key, this.lessonToEdit});

  @override
  ConsumerState<CreateLessonWizardScreen> createState() => _CreateLessonWizardScreenState();
}

class _CreateLessonWizardScreenState extends ConsumerState<CreateLessonWizardScreen> {
  int _currentStep = 0; // 0: Metadatos, 1: Organizador de Ejercicios (Editor)
  bool _isSaving = false;
  String? _editingLessonId;
  bool _showAdvancedSettings = false;

  // STEP 0: METADATOS
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedLanguage = 'Inglés';
  String _selectedDifficulty = 'A1';

  final List<String> _languages = const ['Inglés', 'Alemán', 'Francés', 'Italiano', 'Portugués'];
  final List<String> _difficulties = const ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  @override
  void initState() {
    super.initState();
    if (widget.lessonToEdit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLessonForEditing(widget.lessonToEdit!);
      });
    }
  }

  // STEP 1: SELECCIÓN DE CARTAS
  final Set<String> _selectedCardIds = {};

  // STEP 2: ORGANIZADOR DE EJERCICIOS
  List<LessonExerciseModel> _exercises = [];
  int _selectedExerciseIndex = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _loadLessonForEditing(LessonModel lesson) {
    setState(() {
      _editingLessonId = lesson.id;
      _titleController.text = lesson.title;
      _descriptionController.text = lesson.description ?? '';
      _selectedLanguage = lesson.language;
      _selectedDifficulty = lesson.difficulty;
      _selectedCardIds.clear();
      _selectedCardIds.addAll(lesson.cardIds);
      _exercises = List<LessonExerciseModel>.from(lesson.exercises);
      _selectedExerciseIndex = 0;
    });
    HapticFeedback.lightImpact();
  }

  void _clearEditingMode() {
    setState(() {
      _editingLessonId = null;
      _titleController.clear();
      _descriptionController.clear();
      _selectedLanguage = 'Inglés';
      _selectedDifficulty = 'A1';
      _selectedCardIds.clear();
      _exercises.clear();
      _selectedExerciseIndex = 0;
    });
    HapticFeedback.lightImpact();
  }

  void _confirmDeleteLesson(String lessonId) {
    HapticFeedback.vibrate();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar lección?'),
        content: const Text('Esta acción es irreversible y eliminará la lección de la plataforma.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isSaving = true);
              try {
                await ref.read(lessonServiceProvider).deleteLesson(lessonId);
                ref.invalidate(lessonsListProvider);
                final creatorId = ref.read(authProvider).user?.id ?? '';
                ref.invalidate(userLessonsProvider(creatorId));
                
                if (_editingLessonId == lessonId) {
                  _clearEditingMode();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lección eliminada con éxito.'),
                    backgroundColor: AppColors.online,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar lección: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              } finally {
                setState(() => _isSaving = false);
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  List<Color> _getGradientForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'A1':
      case 'A2':
        return const [Color(0xFF815BF5), Color(0xFF5A45FF)];
      case 'B1':
      case 'B2':
        return const [Color(0xFFFF6B8B), Color(0xFFFF8E53)];
      default:
        return const [Color(0xFF4FA4F4), Color(0xFF4CD9A3)];
    }
  }

  Widget _buildLessonNodePreview({required String title, required String difficulty}) {
    final colors = _getGradientForDifficulty(difficulty);
    final depthColor = Color.alphaBlend(Colors.black.withOpacity(0.25), colors[1]);
    final shadowColor = colors[0].withOpacity(0.25);

    return Container(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: 6,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black26,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            top: 2,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: depthColor,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 6,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsList(List<LessonModel> lessons) {
    if (lessons.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Text(
          'Aún no tienes lecciones creadas.',
          style: TextStyle(color: AppColors.onSurfaceMuted.withOpacity(0.7), fontSize: 13),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        final isSelected = _editingLessonId == lesson.id;
        final colors = _getGradientForDifficulty(lesson.difficulty);
        final depthColor = Color.alphaBlend(Colors.black.withOpacity(0.2), colors[1]);

        return GestureDetector(
          onTap: () => _loadLessonForEditing(lesson),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border.withOpacity(0.6),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.12)
                      : Colors.black.withOpacity(0.01),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                left: 0, right: 0, top: 2, bottom: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: depthColor,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0, right: 0, top: 0, bottom: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: colors,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.menu_book_rounded, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors[0].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            lesson.difficulty,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: colors[0],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                    onPressed: () => _confirmDeleteLesson(lesson.id),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _nextStep(List<WordCardModel> userCards) {
    if (_currentStep == 0) {
      if (_titleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, ingresa un título para la lección.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      setState(() {
        _currentStep = 1;
        _selectedExerciseIndex = 0;
        if (_exercises.isEmpty) {
          _exercises = [
            const LessonExerciseModel(
              id: '1',
              type: ExerciseType.multipleChoice,
              question: 'Select the correct translation',
              correctAnswer: 'Coffee',
              options: ['Tea', 'Water', 'Coffee', 'Juice'],
            ),
            const LessonExerciseModel(
              id: '2',
              type: ExerciseType.translateSentence,
              question: 'Translate: "I want a coffee"',
              correctAnswer: 'I want a coffee',
              correctSequence: ['I', 'want', 'a', 'coffee'],
              options: ['I', 'want', 'a', 'coffee'],
            ),
            const LessonExerciseModel(
              id: '3',
              type: ExerciseType.listeningQuiz,
              question: 'Listen and select the word',
              correctAnswer: 'Coffee',
              options: ['Tea', 'Water', 'Coffee', 'Juice'],
            ),
          ];
        }
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _publishLesson() async {
    if (_exercises.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La lección debe contener al menos 3 ejercicios para ser publicada.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final creatorId = ref.read(authProvider).user?.id ?? '';
      if (_editingLessonId != null) {
        await ref.read(lessonServiceProvider).updateLesson(
              lessonId: _editingLessonId!,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              language: _selectedLanguage,
              difficulty: _selectedDifficulty,
              cardIds: _selectedCardIds.toList(),
              exercisesJson: _exercises.map((e) => e.toJson()).toList(),
            );
      } else {
        await ref.read(lessonServiceProvider).saveLesson(
              creatorId: creatorId,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              language: _selectedLanguage,
              difficulty: _selectedDifficulty,
              cardIds: _selectedCardIds.toList(),
              exercisesJson: _exercises.map((e) => e.toJson()).toList(),
            );
      }

      // Refrescar lista de lecciones si es necesario
      ref.invalidate(lessonsListProvider);
      ref.invalidate(userLessonsProvider(creatorId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(_editingLessonId != null
                  ? '¡Lección actualizada con éxito! 🚀'
                  : '¡Lección publicada con éxito! 🚀'),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la lección: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordCardsAsync = ref.watch(correctWordCardsProvider);
    final userCards = wordCardsAsync.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Degradado superior sutil premium
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
                    AppColors.gradientBgEnd.withValues(alpha: 0.35),
                    AppColors.gradientBgEnd.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encabezado del Wizard
                _buildHeader(),

                // Cuerpo Dinámico del Step
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildStepBody(userCards),
                  ),
                ),
              ],
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  // ENCABEZADO
  Widget _buildHeader() {
    if (_currentStep == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Row(
          children: [
            GestureDetector(
              onTap: _prevStep,
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                color: AppColors.onSurface,
                size: 20,
              ),
            ),
            Expanded(
              child: Text(
                _titleController.text.trim().toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
      );
    }

    // Default metadata header (Step 0)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_rounded,
              color: AppColors.onSurfaceMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _editingLessonId != null ? 'EDITAR LECCIÓN' : 'CREADOR LECCIÓN',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Inter',
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          if (_editingLessonId != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Nueva', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: _clearEditingMode,
            ),
        ],
      ),
    );
  }

  Widget _buildStepBody(List<WordCardModel> userCards) {
    switch (_currentStep) {
      case 0:
        return _buildMetadataStep(userCards);
      case 1:
        return _buildOrganizerStep();
      default:
        return const SizedBox();
    }
  }

  // PASO 0: METADATOS REDISEÑADO
  Widget _buildMetadataStep(List<WordCardModel> userCards) {
    final userId = ref.watch(authProvider).user?.id ?? '';
    final userLessonsAsync = ref.watch(userLessonsProvider(userId));

    return SingleChildScrollView(
      key: const ValueKey('step0'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Text(
            _editingLessonId != null ? 'EDITANDO LECCIÓN' : 'NUEVA LECCIÓN',
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),

          _buildLessonNodePreview(
            title: _titleController.text.trim(),
            difficulty: _selectedDifficulty,
          ),
          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.015),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
              decoration: InputDecoration(
                filled: false,
                fillColor: Colors.transparent,
                hintText: 'Nombre de Lección',
                hintStyle: TextStyle(
                  color: AppColors.onSurfaceMuted.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                'Ajustes adicionales (${_selectedLanguage} • ${_selectedDifficulty})',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
              leading: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
              trailing: Icon(
                _showAdvancedSettings ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary,
              ),
              onExpansionChanged: (val) {
                setState(() => _showAdvancedSettings = val);
              },
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedLanguage,
                          decoration: InputDecoration(
                            labelText: 'Idioma',
                            labelStyle: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _languages.map((l) {
                            return DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedLanguage = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDifficulty,
                          decoration: InputDecoration(
                            labelText: 'Nivel',
                            labelStyle: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _difficulties.map((d) {
                            return DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedDifficulty = val!),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Descripción (Opcional)',
                    labelStyle: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
                    hintText: 'Ej: Aprende las frases de cortesía más usadas por los locales.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildCheckmarkButton(userCards),
          const SizedBox(height: 32),

          Row(
            children: [
              const Text(
                'LECCIONES EN CREACIÓN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceMuted,
                  letterSpacing: 1.0,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 8),
              userLessonsAsync.when(
                data: (lessons) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${lessons.length}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                ),
                loading: () => const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          userLessonsAsync.when(
            data: (lessons) => _buildDraftsList(lessons),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'Error al cargar lecciones: $err',
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCheckmarkButton(List<WordCardModel> userCards) {
    return GestureDetector(
      onTap: () {
        if (_titleController.text.trim().isEmpty) {
          HapticFeedback.vibrate();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, ingresa un título para la lección.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        _nextStep(userCards);
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }



  // PASO 2: ORGANIZADOR DE EJERCICIOS (EDITOR DE LECCIÓN INTERACTIVO)
  Widget _buildOrganizerStep() {
    if (_exercises.isEmpty) {
      return Center(
        key: const ValueKey('step2_empty'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit_note_rounded, size: 64, color: AppColors.onSurfaceMuted),
            const SizedBox(height: 16),
            const Text(
              'No hay pantallas de ejercicios',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface),
            ),
            const SizedBox(height: 8),
            const Text(
              'Añade un ejercicio para comenzar a editar la lección.',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear Primer Ejercicio'),
              onPressed: () => _addExerciseOfType(ExerciseType.multipleChoice),
            ),
          ],
        ),
      );
    }

    final activeExercise = _selectedExerciseIndex < _exercises.length 
        ? _exercises[_selectedExerciseIndex]
        : _exercises[0];

    return Column(
      key: const ValueKey('step2_editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Lista horizontal de mini pantallas de ejercicios (Boceto)
        _buildHorizontalThumbnails(),

        // 2. Simulador de Pantalla del Ejercicio (Centro del Boceto)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _buildMockPhoneEditor(activeExercise),
          ),
        ),

        // 3. Cinta de Herramientas (Abajo del Boceto)
        _buildToolbar(activeExercise),
      ],
    );
  }

  // Lista Horizontal de Miniaturas (Pantallas)
  Widget _buildHorizontalThumbnails() {
    return Container(
      height: 104,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _exercises.length + 1,
        itemBuilder: (context, index) {
          if (index == _exercises.length) {
            return _buildAddExerciseButton();
          }

          final exercise = _exercises[index];
          final isSelected = index == _selectedExerciseIndex;
          
          return _buildScreenThumbnailItem(index, exercise, isSelected);
        },
      ),
    );
  }

  Widget _buildScreenThumbnailItem(int index, LessonExerciseModel exercise, bool isSelected) {
    final typeColor = _getExerciseColor(exercise.type);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedExerciseIndex = index;
        });
        HapticFeedback.lightImpact();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 96,
            margin: const EdgeInsets.only(right: 12, top: 4, left: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border.withValues(alpha: 0.6),
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected 
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PÁG ${index + 1}',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  _getExerciseIcon(exercise.type),
                  color: isSelected ? AppColors.primary : typeColor.withValues(alpha: 0.85),
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  _getShortExerciseTypeName(exercise.type),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          if (_exercises.length > 1)
            Positioned(
              top: -2,
              right: 6,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _exercises.removeAt(index);
                    if (_selectedExerciseIndex >= _exercises.length) {
                      _selectedExerciseIndex = _exercises.length - 1;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(3.0),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddExerciseButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _showAddExerciseOptionsBottomSheet();
      },
      child: Container(
        width: 72,
        height: 96,
        margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4, left: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border,
            width: 1.5,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            SizedBox(height: 6),
            Text(
              'Añadir',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExerciseOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'AÑADIR EJERCICIO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 1.0,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),
              _buildAddExerciseOptionItem(
                icon: Icons.quiz_rounded,
                title: 'Opción Múltiple',
                description: 'Seleccionar la respuesta correcta entre varias opciones.',
                color: const Color(0xFF815BF5),
                onTap: () => _addExerciseOfType(ExerciseType.multipleChoice),
              ),
              _buildAddExerciseOptionItem(
                icon: Icons.volume_up_rounded,
                title: 'Comprensión Auditiva',
                description: 'Escuchar un audio y responder a la pregunta.',
                color: const Color(0xFF4FA4F4),
                onTap: () => _addExerciseOfType(ExerciseType.listeningQuiz),
              ),
              _buildAddExerciseOptionItem(
                icon: Icons.sort_rounded,
                title: 'Reconstrucción de Oración',
                description: 'Ordenar bloques de palabras para formar la frase correcta.',
                color: const Color(0xFFFF6B8B),
                onTap: () => _addExerciseOfType(ExerciseType.translateSentence),
              ),
              _buildAddExerciseOptionItem(
                icon: Icons.mic_rounded,
                title: 'Pronunciación',
                description: 'Hablar por el micrófono para validar la pronunciación.',
                color: const Color(0xFF4CD9A3),
                onTap: () => _addExerciseOfType(ExerciseType.mnemonicMatch),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddExerciseOptionItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
      subtitle: Text(description, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _addExerciseOfType(ExerciseType type) {
    final newExercise = LessonExerciseModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      question: type == ExerciseType.listeningQuiz 
          ? '¿Qué significa esta palabra?'
          : type == ExerciseType.translateSentence
              ? 'Traduce: "I want a coffee"'
              : 'Selecciona la traducción correcta',
      correctAnswer: 'Coffee',
      options: const ['Tea', 'Water', 'Coffee', 'Juice'],
      correctSequence: type == ExerciseType.translateSentence ? const ['I', 'want', 'a', 'coffee'] : null,
    );
    setState(() {
      _exercises.add(newExercise);
      _selectedExerciseIndex = _exercises.length - 1;
    });
    HapticFeedback.mediumImpact();
  }

  // Simulador del Teléfono / Mock Preview Editor
  Widget _buildMockPhoneEditor(LessonExerciseModel exercise) {
    final typeColor = _getExerciseColor(exercise.type);
    return Center(
      child: Container(
        width: 300,
        height: 440,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF0F172A), width: 6.0), // Bisel del celular
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              // Notch/Camara
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 60,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                ),
              ),
              // Contenido Interno
              Padding(
                padding: const EdgeInsets.only(top: 32, left: 24, right: 24, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                           decoration: BoxDecoration(
                             color: typeColor.withValues(alpha: 0.12),
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: Text(
                             _getExerciseTypeName(exercise.type).toUpperCase(),
                             style: TextStyle(
                               fontSize: 7.5,
                               fontWeight: FontWeight.bold,
                               color: typeColor,
                               letterSpacing: 0.5,
                             ),
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 12),
                     // Editor de Instrucción/Pregunta "in-place"
                     TextFormField(
                       key: ValueKey('question-$_selectedExerciseIndex-${exercise.id}'),
                       initialValue: exercise.question,
                       textAlign: TextAlign.center,
                       maxLines: 2,
                       style: const TextStyle(
                         color: AppColors.onSurface,
                         fontSize: 13,
                         fontWeight: FontWeight.bold,
                         fontFamily: 'Inter',
                       ),
                       decoration: InputDecoration(
                         hintText: 'Instrucción del ejercicio...',
                         hintStyle: TextStyle(color: AppColors.onSurfaceMuted.withValues(alpha: 0.5)),
                         border: InputBorder.none,
                         isDense: true,
                         contentPadding: EdgeInsets.zero,
                       ),
                       onChanged: (val) {
                         _updateExercise(exercise.copyWith(question: val.trim()));
                       },
                     ),
                     const SizedBox(height: 12),
                     // Contenido interactivo según tipo
                     Expanded(
                       child: SingleChildScrollView(
                         child: _buildExerciseInteractiveBody(exercise),
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

  Widget _buildExerciseInteractiveBody(LessonExerciseModel exercise) {
    switch (exercise.type) {
      case ExerciseType.listeningQuiz:
      case ExerciseType.multipleChoice:
        return _buildOptionsInteractiveEditor(exercise);
      case ExerciseType.translateSentence:
        return _buildTranslateInteractiveEditor(exercise);
      case ExerciseType.mnemonicMatch:
        return _buildMnemonicInteractiveEditor(exercise);
    }
  }

  Widget _buildOptionsInteractiveEditor(LessonExerciseModel exercise) {
    final typeColor = _getExerciseColor(exercise.type);
    return Column(
      children: [
        if (exercise.type == ExerciseType.listeningQuiz) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.volume_up_rounded, color: typeColor, size: 24),
          ),
        ],
        ...List.generate(exercise.options.length, (optIndex) {
          final optionText = exercise.options[optIndex];
          final isCorrect = optionText == exercise.correctAnswer;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isCorrect ? const Color(0xFFDCFCE7) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCorrect ? const Color(0xFF22C55E) : AppColors.border.withValues(alpha: 0.6),
                width: isCorrect ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _updateExercise(exercise.copyWith(correctAnswer: optionText));
                  },
                  child: Icon(
                    isCorrect ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                    color: isCorrect ? const Color(0xFF22C55E) : AppColors.onSurfaceMuted,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('opt-$_selectedExerciseIndex-$optIndex-${exercise.id}'),
                    initialValue: optionText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                      color: isCorrect ? const Color(0xFF15803D) : AppColors.onSurface,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      final updatedOptions = List<String>.from(exercise.options);
                      updatedOptions[optIndex] = val.trim();
                      final String newCorrectAnswer = isCorrect ? val.trim() : exercise.correctAnswer;
                      
                      _updateExercise(exercise.copyWith(
                        options: updatedOptions,
                        correctAnswer: newCorrectAnswer,
                      ));
                    },
                  ),
                ),
                if (exercise.options.length > 2)
                  GestureDetector(
                    onTap: () {
                      final updatedOptions = List<String>.from(exercise.options);
                      updatedOptions.removeAt(optIndex);
                      String newCorrectAnswer = exercise.correctAnswer;
                      if (isCorrect) {
                        newCorrectAnswer = updatedOptions[0];
                      }
                      _updateExercise(exercise.copyWith(
                        options: updatedOptions,
                        correctAnswer: newCorrectAnswer,
                      ));
                    },
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 14,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTranslateInteractiveEditor(LessonExerciseModel exercise) {
    final words = exercise.correctSequence ?? exercise.correctAnswer.split(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ORACIÓN CORRECTA:',
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextFormField(
            key: ValueKey('translate-ans-$_selectedExerciseIndex-${exercise.id}'),
            initialValue: exercise.correctAnswer,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            maxLines: 2,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) {
              final newWords = val.trim().split(' ').where((w) => w.isNotEmpty).toList();
              _updateExercise(exercise.copyWith(
                correctAnswer: val.trim(),
                correctSequence: newWords,
                options: newWords,
              ));
            },
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'BLOQUES DE PALABRAS:',
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: words.map((word) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                word,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMnemonicInteractiveEditor(LessonExerciseModel exercise) {
    final typeColor = _getExerciseColor(exercise.type);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mic_rounded, color: typeColor, size: 30),
        ),
        const SizedBox(height: 12),
        const Text(
          'TEXTO A PRONUNCIAR:',
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextFormField(
            key: ValueKey('mnemonic-ans-$_selectedExerciseIndex-${exercise.id}'),
            initialValue: exercise.correctAnswer,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) {
              _updateExercise(exercise.copyWith(correctAnswer: val.trim()));
            },
          ),
        ),
      ],
    );
  }

  void _updateExercise(LessonExerciseModel newExercise) {
    setState(() {
      _exercises[_selectedExerciseIndex] = newExercise;
    });
  }

  // Cinta de Herramientas / Toolbar
  Widget _buildToolbar(LessonExerciseModel exercise) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 10
            : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.8), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          _buildToolbarButton(
            icon: Icons.swap_horiz_rounded,
            label: 'Tipo',
            onTap: () => _showChangeTypeMenu(exercise),
          ),
          const SizedBox(width: 24),
          _buildToolbarButton(
            icon: Icons.copy_rounded,
            label: 'Clonar',
            onTap: () {
              HapticFeedback.mediumImpact();
              final duplicated = LessonExerciseModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                type: exercise.type,
                question: exercise.question,
                correctAnswer: exercise.correctAnswer,
                options: List<String>.from(exercise.options),
                correctSequence: exercise.correctSequence != null
                    ? List<String>.from(exercise.correctSequence!)
                    : null,
                audioUrl: exercise.audioUrl,
              );
              setState(() {
                _exercises.insert(_selectedExerciseIndex + 1, duplicated);
                _selectedExerciseIndex += 1;
              });
            },
          ),
          const SizedBox(width: 24),
          if (exercise.type == ExerciseType.multipleChoice || exercise.type == ExerciseType.listeningQuiz)
            _buildToolbarButton(
              icon: Icons.add_box_outlined,
              label: 'Opción',
              onTap: () {
                if (exercise.options.length >= 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Máximo de 6 opciones alcanzado.')),
                  );
                  return;
                }
                HapticFeedback.lightImpact();
                final updatedOptions = List<String>.from(exercise.options);
                updatedOptions.add('Nueva Opción ${updatedOptions.length + 1}');
                _updateExercise(exercise.copyWith(options: updatedOptions));
              },
            ),
          const Spacer(),
          GestureDetector(
            onTap: _publishLesson,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0F172A),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final bool isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isDisabled ? Colors.grey.shade300 : Colors.grey.shade700,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDisabled ? Colors.grey.shade300 : Colors.grey.shade600,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeTypeMenu(LessonExerciseModel exercise) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cambiar tipo de ejercicio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          children: ExerciseType.values.map((type) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _updateExercise(exercise.copyWith(type: type));
                HapticFeedback.mediumImpact();
              },
              child: Row(
                children: [
                  Icon(_getExerciseIcon(type), color: _getExerciseColor(type), size: 16),
                  const SizedBox(width: 12),
                  Text(_getExerciseTypeName(type), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _getShortExerciseTypeName(ExerciseType type) {
    switch (type) {
      case ExerciseType.listeningQuiz:
        return 'Audio';
      case ExerciseType.translateSentence:
        return 'Oración';
      case ExerciseType.multipleChoice:
        return 'Quiz';
      case ExerciseType.mnemonicMatch:
        return 'Micro';
    }
  }



  // HELPERS
  String _getExerciseTypeName(ExerciseType type) {
    switch (type) {
      case ExerciseType.listeningQuiz:
        return 'Comprensión Auditiva';
      case ExerciseType.translateSentence:
        return 'Reconstrucción de Frase';
      case ExerciseType.multipleChoice:
        return 'Opción Múltiple';
      case ExerciseType.mnemonicMatch:
        return 'Pronunciación';
    }
  }

  IconData _getExerciseIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.listeningQuiz:
        return Icons.volume_up_rounded;
      case ExerciseType.translateSentence:
        return Icons.sort_rounded;
      case ExerciseType.multipleChoice:
        return Icons.quiz_rounded;
      case ExerciseType.mnemonicMatch:
        return Icons.mic_rounded;
    }
  }

  Color _getExerciseColor(ExerciseType type) {
    switch (type) {
      case ExerciseType.listeningQuiz:
        return const Color(0xFF4FA4F4);
      case ExerciseType.translateSentence:
        return const Color(0xFFFF6B8B);
      case ExerciseType.multipleChoice:
        return const Color(0xFF815BF5);
      case ExerciseType.mnemonicMatch:
        return const Color(0xFF4CD9A3);
    }
  }
}
