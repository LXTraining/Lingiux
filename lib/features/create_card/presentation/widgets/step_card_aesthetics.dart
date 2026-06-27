import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class StepCardAesthetics extends StatelessWidget {
  final Uint8List? imageBytes;
  final String wordText;
  final int selectedGradientIndex;
  final ValueChanged<int> onGradientChanged;
  final String selectedFrameType;
  final ValueChanged<String> onFrameChanged;

  // Lista de gradientes predefinidos consistentes con word_detail_screen
  static const List<List<Color>> _gradients = [
    [Color(0xFF6366F1), Color(0xFF3B82F6)], // Indigo-Blue
    [Color(0xFF8B5CF6), Color(0xFFEC4899)], // Purple-Pink
    [Color(0xFF10B981), Color(0xFF059669)], // Emerald
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Amber
    [Color(0xFFF43F5E), Color(0xFFEF4444)], // Rose-Red
    [Color(0xFF14B8A6), Color(0xFF0D9488)], // Teal
  ];

  // Lista de marcos decorativos soportados
  static const List<Map<String, String>> _frames = [
    {'type': 'normal', 'label': 'Normal'},
    {'type': 'bronce', 'label': 'Bronce'},
    {'type': 'plata', 'label': 'Plata'},
    {'type': 'oro', 'label': 'Oro'},
    {'type': 'neon', 'label': 'Neón'},
  ];

  const StepCardAesthetics({
    super.key,
    required this.imageBytes,
    required this.wordText,
    required this.selectedGradientIndex,
    required this.onGradientChanged,
    required this.selectedFrameType,
    required this.onFrameChanged,
  });

  // Método auxiliar para renderizar el marco decorativo según el tipo seleccionado
  Widget _buildFrameDecoration(String type, Widget child) {
    if (type == 'normal') {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
        ),
        child: child,
      );
    }

    Color frameColor;
    Color glowColor;
    double borderWidth = 6.0;
    List<BoxShadow> shadows = [];

    switch (type) {
      case 'bronce':
        frameColor = const Color(0xFFCD7F32);
        glowColor = const Color(0xFF8B5A2B);
        shadows = [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ];
        break;
      case 'plata':
        frameColor = const Color(0xFFD4AF37).withValues(alpha: 0.2); // Plata metalizado
        frameColor = const Color(0xFFE0E0E0);
        glowColor = const Color(0xFF9E9E9E);
        shadows = [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 1.5,
          )
        ];
        break;
      case 'oro':
        frameColor = const Color(0xFFFFD700);
        glowColor = const Color(0xFFDAA520);
        shadows = [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.55),
            blurRadius: 14,
            spreadRadius: 2.5,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
        ];
        break;
      case 'neon':
        frameColor = const Color(0xFFEC4899); // Rosa Neón
        glowColor = const Color(0xFFEC4899);
        shadows = [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.6),
            blurRadius: 16,
            spreadRadius: 3.5,
          ),
        ];
        borderWidth = 5.0;
        break;
      default:
        return child;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: frameColor, width: borderWidth),
        boxShadow: shadows,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[selectedGradientIndex % _gradients.length];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Personalización Estética',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Personaliza el diseño visual de tu tarjeta eligiendo un fondo degradado y un marco especial de clasificación.',
            style: TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // PREVISUALIZACIÓN DE LA TARJETA EN TIEMPO REAL
          Center(
            child: Container(
              width: 190,
              height: 270,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _buildFrameDecoration(
                selectedFrameType,
                ClipRRect(
                  borderRadius: BorderRadius.circular(18), // Ajuste por borde grueso
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fondo degradado base
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Imagen superpuesta con opacidad si existe
                      if (imageBytes != null) ...[
                        Image.memory(
                          imageBytes!,
                          fit: BoxFit.cover,
                        ),
                        // Filtro oscuro de contraste
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.70),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      // Texto de la palabra
                      Positioned(
                        bottom: 24,
                        left: 16,
                        right: 16,
                        child: Text(
                          wordText.isNotEmpty ? wordText : 'Palabra',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                offset: Offset(0, 1),
                                blurRadius: 4.0,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // SELECCIÓN DE GRADIENTE DE FONDO
          const Text(
            'Paleta de Colores de Fondo',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _gradients.length,
              itemBuilder: (context, index) {
                final isSelected = selectedGradientIndex == index;
                final gradColors = _gradients[index];

                return GestureDetector(
                  onTap: () => onGradientChanged(index),
                  child: Container(
                    width: 48,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: gradColors[0].withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // SELECCIÓN DEL MARCO DECORATIVO
          const Text(
            'Marco de Clasificación',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _frames.length,
              itemBuilder: (context, index) {
                final frame = _frames[index];
                final type = frame['type']!;
                final label = frame['label']!;
                final isSelected = selectedFrameType == type;

                Color activeColor = AppColors.primary;
                if (type == 'bronce') activeColor = const Color(0xFFCD7F32);
                if (type == 'plata') activeColor = const Color(0xFF9E9E9E);
                if (type == 'oro') activeColor = const Color(0xFFFFD700);
                if (type == 'neon') activeColor = const Color(0xFFEC4899);

                return GestureDetector(
                  onTap: () => onFrameChanged(type),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeColor.withValues(alpha: 0.15)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? activeColor : AppColors.border.withValues(alpha: 0.3),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? activeColor : AppColors.onSurfaceMuted,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
