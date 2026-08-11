import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../../../vocabulary/domain/models/word_card_model.dart';
import '../providers/lessons_provider.dart';
import '../../domain/compiler/lesson_compiler.dart';
import '../../domain/models/lesson_exercise_model.dart';
import '../../../../core/constants/app_colors.dart';

class CreateLessonWizardScreen extends ConsumerStatefulWidget {
  const CreateLessonWizardScreen({super.key});

  @override
  ConsumerState<CreateLessonWizardScreen> createState() => _CreateLessonWizardScreenState();
}

class _CreateLessonWizardScreenState extends ConsumerState<CreateLessonWizardScreen> {
  int _currentStep = 0; // 0: Metadatos, 1: Selección de Cartas, 2: Organizador de Ejercicios
  bool _isSaving = false;

  // STEP 0: METADATOS
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedLanguage = 'Inglés';
  String _selectedDifficulty = 'A1';

  final List<String> _languages = const ['Inglés', 'Alemán', 'Francés', 'Italiano', 'Portugués'];
  final List<String> _difficulties = const ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  // STEP 1: SELECCIÓN DE CARTAS
  final Set<String> _selectedCardIds = {};

  // STEP 2: ORGANIZADOR DE EJERCICIOS
  List<LessonExerciseModel> _exercises = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_selectedCardIds.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecciona al menos 2 cartas para auto-generar ejercicios.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Auto-generación de ejercicios usando el compilador inteligente
      final selectedCards = userCards.where((c) => _selectedCardIds.contains(c.id)).toList();
      final generated = LessonCompiler.compile(cards: selectedCards);

      setState(() {
        _exercises = generated;
        _currentStep = 2;
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
      await ref.read(lessonServiceProvider).saveLesson(
            creatorId: creatorId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            language: _selectedLanguage,
            difficulty: _selectedDifficulty,
            cardIds: _selectedCardIds.toList(),
            exercisesJson: _exercises.map((e) => e.toJson()).toList(),
          );

      // Refrescar lista de lecciones si es necesario
      ref.invalidate(lessonsListProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('¡Lección publicada con éxito! 🚀'),
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

  // DIÁLOGO PARA EDITAR EJERCICIO INDIVIDUAL
  void _showEditExerciseDialog(int index) {
    final exercise = _exercises[index];
    final questionCtrl = TextEditingController(text: exercise.question);
    final correctCtrl = TextEditingController(text: exercise.correctAnswer);

    // Copias editables de opciones
    final options = List<String>.from(exercise.options);
    final optionCtrls = options.map((opt) => TextEditingController(text: opt)).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Editar Ejercicio (${_getExerciseTypeName(exercise.type)})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: questionCtrl,
                  decoration: const InputDecoration(labelText: 'Pregunta / Instrucción'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: correctCtrl,
                  decoration: const InputDecoration(labelText: 'Respuesta Correcta'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Opciones de Respuesta (Distractores):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.onSurfaceMuted),
                ),
                const SizedBox(height: 8),
                ...List.generate(optionCtrls.length, (idx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      controller: optionCtrls[idx],
                      decoration: InputDecoration(
                        labelText: 'Opción ${idx + 1}',
                        isDense: true,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final newOptions = optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

                setState(() {
                  _exercises[index] = LessonExerciseModel(
                    id: exercise.id,
                    type: exercise.type,
                    question: questionCtrl.text.trim(),
                    correctAnswer: correctCtrl.text.trim(),
                    options: newOptions,
                    audioUrl: exercise.audioUrl,
                    correctSequence: exercise.correctSequence,
                  );
                });

                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    ).then((_) {
      // Liberar controladores
      questionCtrl.dispose();
      correctCtrl.dispose();
      for (final c in optionCtrls) {
        c.dispose();
      }
    });
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

                // Barra Inferior de Navegación
                _buildBottomNavigation(userCards),
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
    String stepTitle = '';
    double progress = 0.0;

    switch (_currentStep) {
      case 0:
        stepTitle = 'INFORMACIÓN DE LECCIÓN';
        progress = 0.33;
        break;
      case 1:
        stepTitle = 'SELECCIÓN DE CARTAS';
        progress = 0.66;
        break;
      case 2:
        stepTitle = 'ORGANIZADOR DE EJERCICIOS';
        progress = 1.0;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
              Text(
                stepTitle,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Inter',
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                'Paso ${_currentStep + 1} de 3',
                style: const TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 11,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.border.withValues(alpha: 0.5),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // CUERPO DEL PASO ACTIVO
  Widget _buildStepBody(List<WordCardModel> userCards) {
    switch (_currentStep) {
      case 0:
        return _buildMetadataStep();
      case 1:
        return _buildCardSelectionStep(userCards);
      case 2:
        return _buildOrganizerStep();
      default:
        return const SizedBox();
    }
  }

  // PASO 0: METADATOS
  Widget _buildMetadataStep() {
    return SingleChildScrollView(
      key: const ValueKey('step0'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Comencemos con lo básico',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nombra tu lección e indica el idioma y nivel de dificultad para que la comunidad sepa de qué trata.',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Título
          const Text(
            'TÍTULO DE LA LECCIÓN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: const InputDecoration(
              hintText: 'Ej: Pedir comida en un restaurante 🍔',
            ),
          ),
          const SizedBox(height: 20),

          // Descripción
          const Text(
            'DESCRIPCIÓN (OPCIONAL)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: AppColors.onSurface),
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ej: Aprende las frases de cortesía más usadas por los locales.',
            ),
          ),
          const SizedBox(height: 20),

          // Selectores
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IDIOMA',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedLanguage,
                      items: _languages.map((l) {
                        return DropdownMenuItem(value: l, child: Text(l));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedLanguage = val!),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NIVEL DE DIFICULTAD',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedDifficulty,
                      items: _difficulties.map((d) {
                        return DropdownMenuItem(value: d, child: Text(d));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedDifficulty = val!),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // PASO 1: SELECCIÓN DE CARTAS
  Widget _buildCardSelectionStep(List<WordCardModel> userCards) {
    if (userCards.isEmpty) {
      return Center(
        key: const ValueKey('step1_empty'),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_motion_rounded, size: 64, color: AppColors.onSurfaceMuted),
              const SizedBox(height: 16),
              const Text(
                'No tienes cartas creadas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              const Text(
                'Para compilar una lección necesitas haber creado previamente al menos 2 cartas de vocabulario.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('step1_list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona las cartas semilla',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Elegidas: ${_selectedCardIds.length} cartas. Utilizaremos sus audios, significados y frases para tejer la lección.',
                style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: userCards.length,
            itemBuilder: (context, index) {
              final card = userCards[index];
              final isSelected = _selectedCardIds.contains(card.id);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedCardIds.remove(card.id);
                    } else {
                      _selectedCardIds.add(card.id);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border.withValues(alpha: 0.6),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected 
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.005),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  card.category?.toUpperCase() ?? 'VOCABLO',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (card.audioUrl != null && card.audioUrl!.isNotEmpty)
                                const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 14),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            card.word,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            card.definition,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.onSurfaceMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      if (isSelected)
                        const Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // PASO 2: ORGANIZADOR DE EJERCICIOS
  Widget _buildOrganizerStep() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Organizador de Ejercicios',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Reordena, edita o borra las preguntas generadas. Ejercicios activos: ${_exercises.length}',
                style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: _exercises.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _exercises.removeAt(oldIndex);
                _exercises.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final exercise = _exercises[index];
              return Card(
                key: ValueKey(exercise.id),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getExerciseColor(exercise.type).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getExerciseIcon(exercise.type),
                      color: _getExerciseColor(exercise.type),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    exercise.question,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'R: ${exercise.correctAnswer}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.onSurfaceMuted, size: 18),
                        onPressed: () => _showEditExerciseDialog(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                        onPressed: () {
                          setState(() {
                            _exercises.removeAt(index);
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.drag_indicator_rounded, color: AppColors.border),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // BOTÓN DE NAVEGACIÓN INFERIOR
  Widget _buildBottomNavigation(List<WordCardModel> userCards) {
    final isLastStep = _currentStep == 2;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  side: const BorderSide(color: AppColors.border),
                ),
                onPressed: _prevStep,
                child: const Text(
                  'ATRÁS',
                  style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastStep ? AppColors.primary : const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 0,
              ),
              onPressed: isLastStep ? _publishLesson : () => _nextStep(userCards),
              child: Text(
                isLastStep 
                    ? 'PUBLICAR LECCIÓN' 
                    : _currentStep == 1 
                        ? 'COMPILAR EJERCICIOS' 
                        : 'SIGUIENTE',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
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
