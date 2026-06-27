import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';

class StepWordMnemonics extends StatefulWidget {
  final Uint8List? imageBytes;
  final String? imageName;
  final ValueChanged<Map<String, dynamic>?> onImageSelected;
  final TextEditingController definitionController;
  final TextEditingController exampleController;
  final String wordText; // Para mostrarla arriba en la previsualización del lienzo

  const StepWordMnemonics({
    super.key,
    required this.imageBytes,
    required this.imageName,
    required this.onImageSelected,
    required this.definitionController,
    required this.exampleController,
    required this.wordText,
  });

  @override
  State<StepWordMnemonics> createState() => _StepWordMnemonicsState();
}

class _StepWordMnemonicsState extends State<StepWordMnemonics> {
  final ImagePicker _picker = ImagePicker();

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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nemotecnia y Definición',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Selecciona una imagen de tu galería que te ayude a recordar la palabra de forma visual y escribe su significado.',
            style: TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Lienzo de la Carta Interactiva (Selector de Imagen)
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

          // Campo: Definición/Traducción
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
              hintText: 'Ej. Animal doméstico de la familia de los cánidos...',
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

          // Campo: Frase de ejemplo
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
              hintText: 'Ej. The dog is barking in the garden.',
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
    // Borde redondeado dashed
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
