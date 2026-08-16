import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum PatternType { blobs, grid, lines, stars }

class StoryTheme {
  final String name;
  final String id;
  final List<Color> gradientColors;
  final Color topRightBlobColor;
  final Color bottomLeftBlobColor;
  final Color textColor;
  final Color primaryTextColor;
  final Color iconColor;
  final bool isDark;
  final PatternType patternType;

  const StoryTheme({
    required this.name,
    required this.id,
    required this.gradientColors,
    this.topRightBlobColor = Colors.transparent,
    this.bottomLeftBlobColor = Colors.transparent,
    required this.textColor,
    required this.primaryTextColor,
    required this.iconColor,
    required this.isDark,
    required this.patternType,
  });
}

class StoryBackgroundWidget extends StatelessWidget {
  final String themeId;
  final Widget child;

  const StoryBackgroundWidget({
    super.key,
    required this.themeId,
    required this.child,
  });

  static const List<StoryTheme> themes = [
    // Predefinidos de colores con blobs (círculos)
    StoryTheme(
      name: 'Pergamino (Clásico)',
      id: 'parchment',
      gradientColors: [Color(0xFFFDFBF7), Color(0xFFF5EDE0)],
      topRightBlobColor: Color(0xFFEADCC9),
      bottomLeftBlobColor: Color(0xFFDCD3FF),
      textColor: AppColors.onSurface,
      primaryTextColor: AppColors.primary,
      iconColor: AppColors.onSurface,
      isDark: false,
      patternType: PatternType.blobs,
    ),
    StoryTheme(
      name: 'Atardecer',
      id: 'sunset',
      gradientColors: [Color(0xFFFFF7F5), Color(0xFFFDECE7)],
      topRightBlobColor: Color(0xFFFECDD3),
      bottomLeftBlobColor: Color(0xFFFFEDD5),
      textColor: Color(0xFF4A1525),
      primaryTextColor: Color(0xFFDC2626),
      iconColor: Color(0xFF4A1525),
      isDark: false,
      patternType: PatternType.blobs,
    ),
    StoryTheme(
      name: 'Bosque Zen',
      id: 'forest',
      gradientColors: [Color(0xFFF4F9F4), Color(0xFFE2EFE0)],
      topRightBlobColor: Color(0xFFA7F3D0),
      bottomLeftBlobColor: Color(0xFFD1FAE5),
      textColor: Color(0xFF1E3A1E),
      primaryTextColor: Color(0xFF10B981),
      iconColor: Color(0xFF1E3A1E),
      isDark: false,
      patternType: PatternType.blobs,
    ),
    StoryTheme(
      name: 'Medianoche',
      id: 'midnight',
      gradientColors: [Color(0xFF0F172A), Color(0xFF1E293B)],
      topRightBlobColor: Color(0xFF8B5CF6),
      bottomLeftBlobColor: Color(0xFF06B6D4),
      textColor: Colors.white,
      primaryTextColor: Color(0xFF8B5CF6),
      iconColor: Colors.white,
      isDark: true,
      patternType: PatternType.blobs,
    ),
    // Nuevas propuestas de diseño (Patrones)
    StoryTheme(
      name: 'Cuadrícula Educativa 📐',
      id: 'grid_edu',
      gradientColors: [Color(0xFFFCFBF9), Color(0xFFFAF9F6)],
      textColor: Color(0xFF334155), // Slate 700
      primaryTextColor: AppColors.primary,
      iconColor: Color(0xFF334155),
      isDark: false,
      patternType: PatternType.grid,
    ),
    StoryTheme(
      name: 'Líneas de Libreta 📝',
      id: 'lines_notebook',
      gradientColors: [Color(0xFFFAFAF7), Color(0xFFF6F6F2)],
      textColor: Color(0xFF334155),
      primaryTextColor: AppColors.primary,
      iconColor: Color(0xFF334155),
      isDark: false,
      patternType: PatternType.lines,
    ),
    StoryTheme(
      name: 'Constelación Estelar 🌌',
      id: 'stars_constellation',
      gradientColors: [Color(0xFF0A0F1D), Color(0xFF141B2D)],
      textColor: Colors.white,
      primaryTextColor: Color(0xFF38BDF8), // Light blue / Cyan
      iconColor: Colors.white,
      isDark: true,
      patternType: PatternType.stars,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = themes.firstWhere((t) => t.id == themeId, orElse: () => themes.first);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
        ),
      ),
      child: Stack(
        children: [
          // 1. Blobs/Círculos
          if (theme.patternType == PatternType.blobs) ...[
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.topRightBlobColor.withValues(alpha: theme.isDark ? 0.15 : 0.35),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.bottomLeftBlobColor.withValues(alpha: theme.isDark ? 0.12 : 0.25),
                ),
              ),
            ),
          ],

          // 2. Cuadrícula
          if (theme.patternType == PatternType.grid)
            const Positioned.fill(
              child: GridPatternPainterWidget(color: Color(0xFFE2E8F0)),
            ),

          // 3. Líneas de Libreta
          if (theme.patternType == PatternType.lines)
            const Positioned.fill(
              child: LinesPatternPainterWidget(
                lineColor: Color(0xFFE2E8F0),
                marginColor: Color(0xFFFDA4AF),
              ),
            ),

          // 4. Estrellas
          if (theme.patternType == PatternType.stars)
            const Positioned.fill(
              child: StarsPatternPainterWidget(),
            ),

          child,
        ],
      ),
    );
  }
}

// PAINTERS PERSONALIZADOS

class GridPatternPainterWidget extends StatelessWidget {
  final Color color;
  const GridPatternPainterWidget({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(color),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 0.8;

    const step = 24.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LinesPatternPainterWidget extends StatelessWidget {
  final Color lineColor;
  final Color marginColor;
  const LinesPatternPainterWidget({
    super.key,
    required this.lineColor,
    required this.marginColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LinesPainter(lineColor, marginColor),
    );
  }
}

class _LinesPainter extends CustomPainter {
  final Color lineColor;
  final Color marginColor;
  _LinesPainter(this.lineColor, this.marginColor);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..strokeWidth = 0.8;

    final marginPaint = Paint()
      ..color = marginColor.withValues(alpha: 0.4)
      ..strokeWidth = 1.2;

    const step = 26.0;

    for (double y = 60.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    canvas.drawLine(Offset(40, 0), Offset(40, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StarsPatternPainterWidget extends StatelessWidget {
  const StarsPatternPainterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarsPainter(),
    );
  }
}

class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final random = _SimpleRandom(42); 

    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 1.0 + random.nextDouble() * 1.5;

      canvas.drawCircle(Offset(x, y), radius, paint);

      if (i % 8 == 0) {
        final glowPaint = Paint()
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), radius * 3.5, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SimpleRandom {
  int seed;
  _SimpleRandom(this.seed);
  double nextDouble() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 2147483647.0;
  }
}
