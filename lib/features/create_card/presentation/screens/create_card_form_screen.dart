import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
}

class _CreateCardFormScreenState extends ConsumerState<CreateCardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _phoneticController = TextEditingController();
  final _categoryController = TextEditingController();
  final _languageController = TextEditingController();
  final _definitionController = TextEditingController();
  final _exampleController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _wordController.dispose();
    _phoneticController.dispose();
    _categoryController.dispose();
    _languageController.dispose();
    _definitionController.dispose();
    _exampleController.dispose();
    super.dispose();
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

      // 3. Guardar la metadata en la tabla word_cards de Supabase
      await supabase.from('word_cards').insert({
        'word': _wordController.text.trim(),
        'phonetic': _phoneticController.text.trim(),
        'definition': _definitionController.text.trim(),
        'image_url': imageUrl,
        'category': _categoryController.text.trim(),
        'language': _languageController.text.trim(),
        'example_sentence': _exampleController.text.trim(),
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
                          const SizedBox(height: 32),

                          // Botón de Enviar
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
}
