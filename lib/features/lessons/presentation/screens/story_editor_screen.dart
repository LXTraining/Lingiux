import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../providers/stories_provider.dart';
import '../widgets/story_background_widget.dart';

class StoryEditorScreen extends ConsumerStatefulWidget {
  const StoryEditorScreen({super.key});

  @override
  ConsumerState<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class StoryEditorToken {
  final String text;
  final bool isWord;
  StoryEditorToken(this.text, this.isWord);
}

class _StoryEditorScreenState extends ConsumerState<StoryEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _selectedLanguage = 'Inglés';
  String _selectedDifficulty = 'A1';
  String _selectedThemeId = 'parchment';
  bool _isSaving = false;

  // Flujo del editor: 0 para edición de texto y configuración, 1 para asociación interactiva
  int _currentStep = 0;
  List<StoryEditorToken> _tokens = [];
  final Map<String, String> _wordExercises = {}; // palabra_en_minuscula -> cardId

  final List<String> _languages = ['Inglés', 'Español', 'Francés', 'Alemán', 'Italiano', 'Portugués'];
  final List<String> _difficulties = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  List<StoryEditorToken> _tokenize(String text) {
    // Regex tolerante para palabras y otros caracteres
    final regExp = RegExp(
      r'([a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ]+)|([^a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ\s]+)|(\s+)',
      multiLine: true,
    );
    final matches = regExp.allMatches(text);
    final List<StoryEditorToken> tokens = [];
    for (final match in matches) {
      final val = match.group(0) ?? '';
      // Se considera palabra interactiva si contiene letras y mide al menos 2 caracteres
      final isWord = match.group(1) != null &&
          val.length >= 2 &&
          !RegExp(r'^\d+$').hasMatch(val);
      tokens.add(StoryEditorToken(val, isWord));
    }
    return tokens;
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _tokens = _tokenize(_contentController.text.trim());
      _currentStep = 1;
    });
  }

  void _prevStep() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = 0;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final storiesService = ref.read(storiesServiceProvider);
      await storiesService.saveStory(
        creatorId: user.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        language: _selectedLanguage,
        difficulty: _selectedDifficulty,
        metadata: {
          'theme_id': _selectedThemeId,
          'word_exercises': _wordExercises,
        },
      );

      ref.invalidate(storiesListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Relato guardado y publicado con éxito! 📚'),
            backgroundColor: AppColors.online,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar relato: $e'),
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

  void _showCardSelectorBottomSheet(String word) {
    final cleanWord = word.replaceAll(RegExp(r"[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ']"), '').toLowerCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return CardSelectorWidget(
          word: cleanWord,
          initialAssociatedCardId: _wordExercises[cleanWord],
          onAssociated: (cardId) {
            setState(() {
              _wordExercises[cleanWord] = cardId;
            });
            Navigator.pop(context);
          },
          onDisassociated: () {
            setState(() {
              _wordExercises.remove(cleanWord);
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = StoryBackgroundWidget.themes.firstWhere(
      (t) => t.id == _selectedThemeId,
      orElse: () => StoryBackgroundWidget.themes.first,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.onSurface, size: 20),
          onPressed: () {
            if (_currentStep == 1) {
              _prevStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _currentStep == 0 ? 'NUEVO RELATO' : 'ASOCIAR EJERCICIOS',
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
          if (_currentStep == 0)
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 24),
              tooltip: 'Siguiente paso',
              onPressed: _nextStep,
            )
          else if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_rounded, color: AppColors.primary, size: 24),
              tooltip: 'Guardar relato',
              onPressed: _save,
            )
        ],
      ),
      body: SafeArea(
        child: _currentStep == 0 ? _buildStep0Form() : _buildStep1InteractiveEditor(activeTheme),
      ),
    );
  }

  Widget _buildStep0Form() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título
            TextFormField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Título del relato...',
                hintStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                  color: AppColors.onSurfaceMuted.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor, introduce un título.';
                }
                return null;
              },
            ),
            const Divider(height: 20, color: AppColors.border),
            const SizedBox(height: 12),

            // Selectores de Idioma y Nivel
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    decoration: InputDecoration(
                      labelText: 'Idioma',
                      labelStyle: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12, fontFamily: 'Inter'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    items: _languages.map((lang) {
                      return DropdownMenuItem(
                        value: lang,
                        child: Text(lang, style: const TextStyle(fontSize: 14, fontFamily: 'Inter')),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLanguage = val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDifficulty,
                    decoration: InputDecoration(
                      labelText: 'Dificultad',
                      labelStyle: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12, fontFamily: 'Inter'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    items: _difficulties.map((diff) {
                      return DropdownMenuItem(
                        value: diff,
                        child: Text(diff, style: const TextStyle(fontSize: 14, fontFamily: 'Inter')),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDifficulty = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Selector de Fondo
            const Text(
              'Fondo del Relato',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                color: AppColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 86,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: StoryBackgroundWidget.themes.length,
                itemBuilder: (context, index) {
                  final theme = StoryBackgroundWidget.themes[index];
                  final isSelected = theme.id == _selectedThemeId;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedThemeId = theme.id;
                      });
                    },
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: theme.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          if (theme.patternType == PatternType.blobs) ...[
                            Positioned(
                              top: -15,
                              right: -15,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.topRightBlobColor.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -15,
                              left: -15,
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.bottomLeftBlobColor.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ],
                          if (theme.patternType == PatternType.grid)
                            const Positioned.fill(
                              child: GridPatternPainterWidget(color: Color(0xFFE2E8F0)),
                            ),
                          if (theme.patternType == PatternType.lines)
                            const Positioned.fill(
                              child: LinesPatternPainterWidget(
                                lineColor: Color(0xFFE2E8F0),
                                marginColor: Color(0xFFFDA4AF),
                              ),
                            ),
                          if (theme.patternType == PatternType.stars)
                            const Positioned.fill(
                              child: StarsPatternPainterWidget(),
                            ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18)
                                : const SizedBox.shrink(),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 10,
                            right: 10,
                            child: Text(
                              theme.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Contenido
            Container(
              constraints: const BoxConstraints(minHeight: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
              ),
              child: TextFormField(
                controller: _contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontFamily: 'Inter',
                  color: AppColors.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Redacta tu relato aquí...\n\nCuando pases al siguiente paso, podrás seleccionar qué palabras tendrán ejercicios asociados.',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Inter',
                    color: AppColors.onSurfaceMuted.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, introduce el contenido del relato.';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1InteractiveEditor(StoryTheme activeTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner de Instrucciones
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.primary.withOpacity(0.08),
          child: const Row(
            children: [
              Icon(Icons.touch_app_rounded, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Toca cualquier palabra destacable del texto para asociarle un ejercicio interactivo de tus tarjetas guardadas.',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.5,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Área del texto con el fondo del tema seleccionado
        Expanded(
          child: StoryBackgroundWidget(
            themeId: _selectedThemeId,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              physics: const BouncingScrollPhysics(),
              child: Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: _tokens.map((token) {
                  if (!token.isWord) {
                    return Text(
                      token.text,
                      style: TextStyle(
                        fontSize: 16.0,
                        height: 1.6,
                        fontFamily: 'Inter',
                        color: activeTheme.textColor.withValues(alpha: 0.8),
                      ),
                    );
                  }

                  final cleanWord = token.text.replaceAll(RegExp(r"[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ']"), '').toLowerCase();
                  final isAssociated = _wordExercises.containsKey(cleanWord);

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showCardSelectorBottomSheet(token.text);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 2.0),
                      padding: isAssociated
                          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                          : const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                        color: isAssociated
                            ? AppColors.primary.withOpacity(0.16)
                            : Colors.transparent,
                        border: Border.all(
                          color: isAssociated
                              ? AppColors.primary.withOpacity(0.4)
                              : Colors.transparent,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            token.text,
                            style: TextStyle(
                              fontSize: 16.0,
                              height: 1.6,
                              fontFamily: 'Inter',
                              color: isAssociated ? AppColors.primary : activeTheme.textColor,
                              fontWeight: isAssociated ? FontWeight.bold : FontWeight.normal,
                              decoration: isAssociated
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                              decorationStyle: TextDecorationStyle.dashed,
                            ),
                          ),
                          if (isAssociated) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.link_rounded,
                              size: 11,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CardSelectorWidget extends ConsumerStatefulWidget {
  final String word;
  final String? initialAssociatedCardId;
  final ValueChanged<String> onAssociated;
  final VoidCallback onDisassociated;

  const CardSelectorWidget({
    super.key,
    required this.word,
    this.initialAssociatedCardId,
    required this.onAssociated,
    required this.onDisassociated,
  });

  @override
  ConsumerState<CardSelectorWidget> createState() => _CardSelectorWidgetState();
}

class _CardSelectorWidgetState extends ConsumerState<CardSelectorWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wordCardsAsync = ref.watch(wordCardsProvider);

    return wordCardsAsync.when(
      loading: () => const SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, stack) => SizedBox(
        height: 300,
        child: Center(
          child: Text('Error al cargar cartas: $err'),
        ),
      ),
      data: (cards) {
        // Filtrar por búsqueda
        final filteredCards = cards.where((c) {
          if (_searchQuery.isEmpty) return true;
          return c.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.definition.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        // Sugerencias: tarjetas cuyo deletreo coincide exactamente o contiene la palabra buscada
        final exactMatches = filteredCards
            .where((c) => c.word.toLowerCase() == widget.word.toLowerCase())
            .toList();
        
        final otherCards = filteredCards
            .where((c) => c.word.toLowerCase() != widget.word.toLowerCase())
            .toList();

        // Si hay coincidencia exacta, ponerla primero
        final displayCards = [...exactMatches, ...otherCards];

        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Asociar ejercicio a "${widget.word}"',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  if (widget.initialAssociatedCardId != null)
                    TextButton.icon(
                      icon: const Icon(Icons.link_off_rounded, color: AppColors.error, size: 16),
                      label: const Text('Desvincular', style: TextStyle(color: AppColors.error, fontSize: 13)),
                      onPressed: widget.onDisassociated,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Buscador
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar tarjeta por palabra o definición...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.onSurfaceMuted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Listado de cartas
              Expanded(
                child: displayCards.isEmpty
                    ? const Center(
                        child: Text(
                          'No se encontraron tarjetas.',
                          style: TextStyle(color: AppColors.onSurfaceMuted),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: displayCards.length,
                        itemBuilder: (context, index) {
                          final card = displayCards[index];
                          final isCurrentlyAssociated = widget.initialAssociatedCardId == card.id;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isCurrentlyAssociated
                                  ? AppColors.primary.withOpacity(0.08)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCurrentlyAssociated
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: isCurrentlyAssociated ? 1.5 : 1.0,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: card.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        card.imageUrl,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.image_not_supported_rounded, color: AppColors.primary),
                                    ),
                              title: Row(
                                children: [
                                  Text(
                                    card.word,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (card.word.toLowerCase() == widget.word.toLowerCase())
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.online.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Coincidencia',
                                        style: TextStyle(
                                          color: AppColors.online,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  card.definition,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              trailing: isCurrentlyAssociated
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                      ),
                                      onPressed: () => widget.onAssociated(card.id),
                                      child: const Text('Asociar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
