import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';

class ThreeDHorizontalCarousel extends StatefulWidget {
  final VoidCallback onCreateCard;
  final VoidCallback onCreateLesson;
  final VoidCallback onCreateStory;

  const ThreeDHorizontalCarousel({
    key,
    required this.onCreateCard,
    required this.onCreateLesson,
    required this.onCreateStory,
  }) : super(key: key);

  @override
  State<ThreeDHorizontalCarousel> createState() => _ThreeDHorizontalCarouselState();
}

class _ThreeDHorizontalCarouselState extends State<ThreeDHorizontalCarousel>
    with SingleTickerProviderStateMixin {
  
  double _angle = 0.0; // Ángulo central en radianes
  late final AnimationController _animationController;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _animateToAngle(double targetAngle) {
    _animation = Tween<double>(
      begin: _angle,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ))
      ..addListener(() {
        setState(() {
          _angle = _animation!.value;
        });
      });
    
    _animationController.reset();
    _animationController.forward();
  }

  void _snapToNearest() {
    const double segment = 2 * math.pi / 3;
    int closestIndex = (-_angle / segment).round();
    double targetAngle = -closestIndex * segment;
    _animateToAngle(targetAngle);
  }

  void _rotateToItem(int index, VoidCallback onTapAction) {
    const double segment = 2 * math.pi / 3;
    
    // Obtener el índice que está actualmente al frente
    int currentFrontIndex = (-_angle / segment).round();
    int currentActualIndex = ((currentFrontIndex % 3) + 3) % 3;
    
    if (currentActualIndex == index) {
      // Si ya está al frente, abrir la opción
      HapticFeedback.mediumImpact();
      onTapAction();
    } else {
      // Encontrar la dirección de rotación más corta hacia el elemento
      int targetIndex = currentFrontIndex;
      int diffRight = ((index - (targetIndex % 3)) + 3) % 3;
      if (diffRight == 1) {
        targetIndex++;
      } else {
        targetIndex--;
      }
      
      HapticFeedback.lightImpact();
      _animateToAngle(-targetIndex * segment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<_ItemData> items = [
      _ItemData(
        index: 0,
        title: 'Carta',
        tag: 'VOCABULARIO',
        icon: Icons.auto_awesome_motion_rounded,
        gradient: const [Color(0xFF815BF5), Color(0xFF5A45FF)],
        features: const [
          _FeatureRow(icon: Icons.check_circle_outline_rounded, label: 'Formato: Flashcard'),
          _FeatureRow(icon: Icons.psychology_outlined, label: 'Foco: Retención Activa'),
        ],
        onTap: widget.onCreateCard,
      ),
      _ItemData(
        index: 1,
        title: 'Lección',
        tag: 'CAMINOS',
        icon: Icons.map_rounded,
        gradient: const [Color(0xFFFF6B8B), Color(0xFFFF8E53)],
        features: const [
          _FeatureRow(icon: Icons.check_circle_outline_rounded, label: 'Formato: Quizzes'),
          _FeatureRow(icon: Icons.insights_outlined, label: 'Foco: Gamificación'),
        ],
        onTap: widget.onCreateLesson,
      ),
      _ItemData(
        index: 2,
        title: 'Relato',
        tag: 'LECTURAS',
        icon: Icons.auto_stories_rounded,
        gradient: const [Color(0xFF4FA4F4), Color(0xFF4CD9A3)],
        features: const [
          _FeatureRow(icon: Icons.check_circle_outline_rounded, label: 'Formato: Lectura Contextual'),
          _FeatureRow(icon: Icons.translate_rounded, label: 'Foco: Comprensión'),
        ],
        onTap: widget.onCreateStory,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double parentWidth = constraints.maxWidth;
        final double radiusX = parentWidth * 0.26; // Amplitud horizontal de la órbita
        const double cardWidth = 186.0;
        const double cardHeight = 216.0;
        final double centerX = (parentWidth / 2) - (cardWidth / 2);

        // Lista de widgets ordenables por profundidad (Z-Sorting)
        final List<_SortedCard> sortedCards = [];

        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          final double itemAngle = _angle + i * (2 * math.pi / 3);

          // Coordenadas trigonométricas en círculo unitario
          final double x = math.sin(itemAngle);
          final double z = math.cos(itemAngle); // 1.0 (Al Frente), -1.0 (Al Fondo/Atrás)

          // Transformaciones tridimensionales
          final double scale = 0.80 + (z + 1.0) / 2.0 * 0.20; // 0.80 a 1.0
          final double opacity = (0.35 + (z + 1.0) / 2.0 * 0.65).clamp(0.0, 1.0); // 0.35 a 1.0
          final double rotationY = x * -0.42; // Torsión en eje Y al girar
          final double translateY = (1.0 - z) * -16.0; // Desplazamiento hacia arriba para las de atrás
          final double posX = centerX + x * radiusX;

          final cardWidget = Positioned(
            left: posX,
            top: 36 + translateY,
            width: cardWidth,
            height: cardHeight + 36,
            child: Opacity(
              opacity: opacity,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016) // Perspectiva real 3D
                  ..rotateY(rotationY)
                  ..scale(scale),
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Tarjeta Principal (Desplazada hacia abajo para dar espacio al overflow superior)
                    Positioned(
                      top: 28,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.only(top: 36, bottom: 12, left: 14, right: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: z > 0.9
                                ? AppColors.primary.withOpacity(0.5)
                                : AppColors.border.withOpacity(0.8),
                            width: z > 0.9 ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(z > 0.9 ? 0.04 : 0.015),
                              blurRadius: z > 0.9 ? 16 : 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Título y Categoría
                            Column(
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                    color: AppColors.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: item.gradient[0].withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.tag,
                                    style: TextStyle(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Inter',
                                      color: item.gradient[0],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Columnas de Características
                            Column(
                              children: item.features.map((feature) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        feature.icon,
                                        size: 11,
                                        color: item.gradient[0],
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          feature.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontFamily: 'Inter',
                                            color: AppColors.onSurfaceMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),

                            // Botón Ticket de Selección
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: item.gradient[0],
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => _rotateToItem(item.index, item.onTap),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'CREAR',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 10),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Burbuja de Icono Desbordada Arriba
                    Positioned(
                      top: 2, // Desborda por encima del contenedor marginado a 28
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () => _rotateToItem(item.index, item.onTap),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: item.gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: item.gradient[0].withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              item.icon,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          sortedCards.add(_SortedCard(z: z, widget: cardWidget));
        }

        // Z-Sorting: Ordenamos de menor profundidad (más atrás) a mayor profundidad (más adelante)
        // De esta forma las de atrás se pintan primero, y la del frente se dibuja al final quedando arriba.
        sortedCards.sort((a, b) => a.z.compareTo(b.z));

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            _animationController.stop();
            setState(() {
              // Ajustamos la sensibilidad al arrastrar lateralmente
              _angle += details.primaryDelta! * (2 * math.pi / parentWidth) * 0.75;
            });
          },
          onHorizontalDragEnd: (details) {
            _snapToNearest();
          },
          child: Container(
            height: 280,
            color: Colors.transparent, // Asegura que capture los gestos en todo su contenedor
            child: Stack(
              clipBehavior: Clip.none,
              children: sortedCards.map((c) => c.widget).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _ItemData {
  final int index;
  final String title;
  final String tag;
  final IconData icon;
  final List<Color> gradient;
  final List<_FeatureRow> features;
  final VoidCallback onTap;

  _ItemData({
    required this.index,
    required this.title,
    required this.tag,
    required this.icon,
    required this.gradient,
    required this.features,
    required this.onTap,
  });
}

class _FeatureRow {
  final IconData icon;
  final String label;

  const _FeatureRow({
    required this.icon,
    required this.label,
  });
}

class _SortedCard {
  final double z;
  final Widget widget;

  _SortedCard({
    required this.z,
    required this.widget,
  });
}
