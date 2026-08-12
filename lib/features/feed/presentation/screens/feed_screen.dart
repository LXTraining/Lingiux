import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../../../vocabulary/presentation/screens/word_detail_screen.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../home/presentation/providers/navigation_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  late ValueNotifier<double> _sheetExtentNotifier;

  @override
  void initState() {
    super.initState();
    _sheetExtentNotifier = ValueNotifier<double>(0.55);
  }

  @override
  void dispose() {
    _sheetExtentNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Degradado oficial morado/índigo estático
    const gradientColors = [Color(0xFF7C3AED), Color(0xFF4F46E5)];

    // Obtener reactivamente la lista de tarjetas y tomar la primera que ya esté creada
    final wordCardsAsync = ref.watch(wordCardsProvider);
    final cards = wordCardsAsync.value ?? [];
    final targetWord = cards.isNotEmpty ? cards.first.word : 'lingiux';

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
            appBar: AppBar(
              leading: Builder(
                builder: (context) {
                  final profile = ref.watch(profileProvider).value;
                  final avatarUrl = profile?['avatar_url'] as String?;
                  final streakCount = profile?['streak_count'] as int? ?? 0;
                  final fullName = profile?['full_name'] ?? '';
                  final initials = fullName.isNotEmpty
                      ? fullName.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                      : 'LX';

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(homeScaffoldKeyProvider).currentState?.openDrawer();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12.0, top: 10.0, bottom: 10.0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          if (streakCount > 0)
                            Positioned(
                              right: -6,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B8B),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF6B8B).withOpacity(0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '🔥',
                                      style: TextStyle(fontSize: 8),
                                    ),
                                    const SizedBox(width: 1),
                                    Text(
                                      '$streakCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              title: const Text(AppStrings.navInicio),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final bodyHeight = constraints.maxHeight;
                final tamagotchiHeight = bodyHeight * 0.45;

                return Stack(
                  children: [
                    // 1. Tamagotchi Widget en el fondo (ocupa la mitad superior, ~45%)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: tamagotchiHeight,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _sheetExtentNotifier,
                        builder: (context, extent, child) {
                          final tamagotchiOpacity = ((1.0 - extent) / (1.0 - 0.55)).clamp(0.0, 1.0);
                          final scale = 0.8 + 0.2 * tamagotchiOpacity;
                          final offset = -50.0 * (1.0 - tamagotchiOpacity);

                          return Opacity(
                            opacity: tamagotchiOpacity,
                            child: Transform.translate(
                              offset: Offset(0, offset),
                              child: Transform.scale(
                                scale: scale,
                                child: const TamagotchiWidget(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // 2. El panel deslizable transparente (DraggableScrollableSheet)
                    Positioned.fill(
                      child: NotificationListener<DraggableScrollableNotification>(
                        onNotification: (notification) {
                          _sheetExtentNotifier.value = notification.extent;
                          return true;
                        },
                        child: DraggableScrollableSheet(
                          initialChildSize: 0.55,
                          minChildSize: 0.55,
                          maxChildSize: 1.0,
                          snap: true,
                          snapSizes: const [0.55, 1.0],
                          builder: (context, scrollController) {
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                const double rowHeight = 150.0;
                                const double nodeSize = 80.0;
                                const double cardHeight = 76.0;
                                final totalHeight = mockLessons.length * rowHeight + 40.0;

                                // Fracciones de alineación X para el caminito ondulado
                                final xFractions = [0.25, 0.65, 0.35, 0.70, 0.40, 0.65];

                                return SingleChildScrollView(
                                  controller: scrollController,
                                  physics: const ClampingScrollPhysics(),
                                  padding: const EdgeInsets.only(top: 16, bottom: 40),
                                  child: Stack(
                                    children: [
                                      // 1. El camino dibujado con CustomPaint
                                      Positioned.fill(
                                        child: CustomPaint(
                                          size: Size(width, totalHeight),
                                          painter: PathPainter(
                                            xFractions: xFractions,
                                            rowHeight: rowHeight,
                                            itemCount: mockLessons.length,
                                          ),
                                        ),
                                      ),

                                      // 2. Elementos posicionados
                                      SizedBox(
                                        width: width,
                                        height: totalHeight,
                                        child: Stack(
                                          children: [
                                            for (int index = 0; index < mockLessons.length; index++) ...[
                                              // Tarjeta informativa de la lección
                                              Positioned(
                                                top: (index * rowHeight + rowHeight / 2) - cardHeight / 2,
                                                left: (xFractions[index % xFractions.length] < 0.5)
                                                    ? (width * xFractions[index % xFractions.length]) + nodeSize / 2 + 10
                                                    : 20,
                                                right: (xFractions[index % xFractions.length] < 0.5)
                                                    ? 20
                                                    : (width - (width * xFractions[index % xFractions.length])) + nodeSize / 2 + 10,
                                                child: _buildLessonCard(context, mockLessons[index], (xFractions[index % xFractions.length] < 0.5), cardHeight),
                                              ),
                                              // Nodo interactivo de la lección
                                              Positioned(
                                                left: (width * xFractions[index % xFractions.length]) - nodeSize / 2,
                                                top: (index * rowHeight + rowHeight / 2) - nodeSize / 2,
                                                child: LessonNode(
                                                  lesson: mockLessons[index],
                                                  size: nodeSize,
                                                  onTap: () => _showLessonDetailsBottomSheet(context, mockLessons[index]),
                                                ),
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Acceso Directo Flotante: Mini Card Estática que se asoma a la derecha
          Positioned(
            right: -42, // Oculta a la derecha
            top: 140, // Posicionada en la parte superior derecha
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                // Redirige al card scrolling con una carta que ya existe
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WordDetailScreen(selectedWord: targetWord),
                  ),
                );
              },
              child: Transform.rotate(
                angle: -0.06, // Inclinación sutil y estilizada
                child: Opacity(
                  opacity: 0.90, // Opacidad del 90%
                  child: Container(
                    width: 75, // Ancho compacto
                    height: 120, // Altura de 120
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.30),
                          blurRadius: 12,
                          offset: const Offset(-3, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Icono decorativo de estrellas en el centro-izquierdo de la card (estático)
                        Positioned(
                          left: 14,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Icon(
                              Icons.auto_awesome_outlined,
                              size: 24,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
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
    );
  }
}

// ==========================================
// WIDGETS Y PINTORES DE SOPORTE PARA LECCIONES
// ==========================================

Widget _buildLessonCard(BuildContext context, Lesson lesson, bool isLeft, double cardHeight) {
  final isLocked = lesson.isLocked;
  return Container(
    height: cardHeight,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: isLocked
          ? Colors.white.withOpacity(0.5)
          : Colors.white.withOpacity(0.85),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isLocked
            ? AppColors.border.withOpacity(0.4)
            : AppColors.border.withOpacity(0.8),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.015),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lesson.flag,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isLocked
                    ? Colors.grey.shade200
                    : lesson.gradient[0].withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                lesson.category.toUpperCase(),
                style: TextStyle(
                  color: isLocked ? Colors.grey.shade600 : lesson.gradient[0],
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          lesson.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isLocked ? Colors.grey.shade600 : AppColors.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Por ${lesson.creatorName}',
          style: TextStyle(
            color: isLocked ? Colors.grey.shade500 : AppColors.onSurfaceMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
      ],
    ),
  );
}

void _showLessonDetailsBottomSheet(BuildContext context, Lesson lesson) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 14,
          bottom: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: lesson.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    lesson.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            lesson.flag,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            lesson.category.toUpperCase(),
                            style: TextStyle(
                              color: lesson.gradient[0],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lesson.title,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary,
                  backgroundImage: lesson.creatorAvatar != null && lesson.creatorAvatar!.isNotEmpty
                      ? NetworkImage(lesson.creatorAvatar!)
                      : null,
                  child: lesson.creatorAvatar == null || lesson.creatorAvatar!.isEmpty
                      ? Text(
                          lesson.creatorName.isNotEmpty
                              ? lesson.creatorName.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                              : 'LX',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.creatorName,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const Text(
                        'Creador/a verificado/a de la comunidad',
                        style: TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 11,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Qué aprenderás?',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Domina el vocabulario cotidiano y frases de uso común. Practica con audios grabados por hablantes nativos y pon a prueba tu pronunciación usando nuestro analizador de Inteligencia Artificial.',
                    style: TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 12,
                      height: 1.4,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('¡Cargando lección "${lesson.title}"!'),
                    backgroundColor: lesson.gradient[0],
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onSurface,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: const Text(
                '¡Empezar Lección!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class LessonNode extends StatefulWidget {
  final Lesson lesson;
  final double size;
  final VoidCallback onTap;

  const LessonNode({
    super.key,
    required this.lesson,
    required this.size,
    required this.onTap,
  });

  @override
  State<LessonNode> createState() => _LessonNodeState();
}

class _LessonNodeState extends State<LessonNode> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final size = widget.size;
    final isLocked = lesson.isLocked;

    final colors = isLocked
        ? [Colors.grey.shade400, Colors.grey.shade500]
        : lesson.gradient;

    final depthColor = isLocked
        ? Colors.grey.shade600
        : Color.alphaBlend(Colors.black.withOpacity(0.25), colors[1]);

    final Color shadowColor = isLocked
        ? Colors.transparent
        : colors[0].withOpacity(0.25);

    return GestureDetector(
      onTapDown: (_) {
        if (!isLocked) {
          setState(() => _isPressed = true);
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        if (!isLocked) {
          setState(() => _isPressed = false);
          widget.onTap();
        }
      },
      onTapCancel: () {
        if (!isLocked) {
          setState(() => _isPressed = false);
        }
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!isLocked && lesson.progress > 0)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: lesson.progress),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return CustomPaint(
                      painter: ProgressRingPainter(
                        progress: value,
                        color: colors[0],
                      ),
                    );
                  },
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: size - 14,
              height: size - 14,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    top: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: depthColor,
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 60),
                    left: 0,
                    right: 0,
                    top: _isPressed ? 6 : 0,
                    bottom: _isPressed ? 0 : 6,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: _isPressed
                            ? []
                            : [
                                BoxShadow(
                                  color: shadowColor,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Center(
                        child: Icon(
                          isLocked ? Icons.lock_rounded : lesson.icon,
                          color: Colors.white,
                          size: (size - 14) * 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: _buildCreatorBadge(context, lesson),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorBadge(BuildContext context, Lesson lesson) {
    final avatarUrl = lesson.creatorAvatar;
    final initials = lesson.creatorName.isNotEmpty
        ? lesson.creatorName.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'LX';

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.background,
        border: Border.all(color: AppColors.background, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 3,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 12,
        backgroundColor: widget.lesson.isLocked ? Colors.grey.shade400 : AppColors.primary,
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
            ? NetworkImage(avatarUrl)
            : null,
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              )
            : null,
      ),
    );
  }
}

class ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  ProgressRingPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 3.5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final backgroundPaint = Paint()
      ..color = AppColors.border.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, backgroundPaint);

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const double startAngle = -3.1415926535 / 2;
    final double sweepAngle = 2 * 3.1415926535 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class PathPainter extends CustomPainter {
  final List<double> xFractions;
  final double rowHeight;
  final int itemCount;

  PathPainter({
    required this.xFractions,
    required this.rowHeight,
    required this.itemCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (itemCount < 2) return;

    final path = Path();
    
    double startX = size.width * xFractions[0];
    double startY = rowHeight / 2;
    path.moveTo(startX, startY);

    for (int i = 0; i < itemCount - 1; i++) {
      double endX = size.width * xFractions[(i + 1) % xFractions.length];
      double endY = (i + 1) * rowHeight + rowHeight / 2;

      double controlY1 = startY + rowHeight * 0.45;
      double controlY2 = endY - rowHeight * 0.45;
      
      path.cubicTo(startX, controlY1, endX, controlY2, endX, endY);
      
      startX = endX;
      startY = endY;
    }

    // Convertir el camino continuo a punteado (dashed)
    final dashedPath = Path();
    const double dashWidth = 12.0;
    const double dashSpace = 8.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        dashedPath.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    final shadowPaint = Paint()
      ..color = AppColors.border.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(dashedPath, shadowPaint);

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF815BF5),
          Color(0xFFFF6B8B),
          Color(0xFF4FA4F4),
          Color(0xFFA258F5),
          Color(0xFF815BF5),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant PathPainter oldDelegate) => false;
}

class Lesson {
  final String id;
  final String title;
  final String category;
  final String flag;
  final String creatorName;
  final String? creatorAvatar;
  final double progress;
  final bool isLocked;
  final IconData icon;
  final List<Color> gradient;

  const Lesson({
    required this.id,
    required this.title,
    required this.category,
    required this.flag,
    required this.creatorName,
    this.creatorAvatar,
    required this.progress,
    required this.isLocked,
    required this.icon,
    required this.gradient,
  });
}

final mockLessons = [
  const Lesson(
    id: '1',
    title: 'Frases de Supervivencia',
    category: 'Básico 1',
    flag: '🇺🇸',
    creatorName: 'Ana Smith',
    progress: 1.0,
    isLocked: false,
    icon: Icons.chat_bubble_rounded,
    gradient: [Color(0xFF815BF5), Color(0xFF5A45FF)],
  ),
  const Lesson(
    id: '2',
    title: 'Ordenando Tacos al Pastor',
    category: 'Cultura 1',
    flag: '🇲🇽',
    creatorName: 'Carlos López',
    creatorAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150',
    progress: 0.7,
    isLocked: false,
    icon: Icons.restaurant_rounded,
    gradient: [Color(0xFFFF6B8B), Color(0xFFFF8E53)],
  ),
  const Lesson(
    id: '3',
    title: 'Slang Callejero',
    category: 'Modismos',
    flag: '🇨🇱',
    creatorName: 'María Rojas',
    creatorAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150',
    progress: 0.3,
    isLocked: false,
    icon: Icons.record_voice_over_rounded,
    gradient: [Color(0xFFA258F5), Color(0xFFF558C9)],
  ),
  const Lesson(
    id: '4',
    title: 'Entrevista de Trabajo Tech',
    category: 'Profesional',
    flag: '🇬🇧',
    creatorName: 'David Webb',
    creatorAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150',
    progress: 0.0,
    isLocked: true,
    icon: Icons.work_rounded,
    gradient: [Color(0xFF4FA4F4), Color(0xFF4CD9A3)],
  ),
  const Lesson(
    id: '5',
    title: 'El Arte del Coqueteo',
    category: 'Social',
    flag: '🇫🇷',
    creatorName: 'Sophie Dubois',
    creatorAvatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=150',
    progress: 0.0,
    isLocked: true,
    icon: Icons.favorite_rounded,
    gradient: [Color(0xFFFF6B8B), Color(0xFFF558C9)],
  ),
  const Lesson(
    id: '6',
    title: 'Sobrevivir en el Aeropuerto',
    category: 'Viajes',
    flag: '🇩🇪',
    creatorName: 'Hans Müller',
    progress: 0.0,
    isLocked: true,
    icon: Icons.flight_takeoff_rounded,
    gradient: [Color(0xFF815BF5), Color(0xFF4FA4F4)],
  ),
];

// ==========================================
// WIDGET TAMAGOTCHI INTERACTIVO DE INICIO
// ==========================================

class TamagotchiWidget extends StatefulWidget {
  const TamagotchiWidget({super.key});

  @override
  State<TamagotchiWidget> createState() => _TamagotchiWidgetState();
}

class _TamagotchiWidgetState extends State<TamagotchiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  String _currentSpeech = '¡Hola! Ayúdame a nacer completando tu caminito.';
  bool _isPressed = false;

  final List<String> _speeches = [
    '¡Zzz... Lingui está soñando con verbos en inglés!',
    '¡Hola! Cada lección que completas me da energía.',
    '¡Mmm... creo que hoy es un gran día para practicar modismos!',
    '¡Brr! Siento que mi cascarón se agrieta con tu conocimiento.',
    '¡Hii! ¿Sabías que hablar un idioma nuevo abre un cerebro extra?',
    '¡Pst! Si completas tu racha de hoy, tendré un regalo para ti.',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapMascot() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isPressed = true;
      // Seleccionar un mensaje aleatorio distinto al actual
      final random = math.Random();
      String nextSpeech;
      do {
        nextSpeech = _speeches[random.nextInt(_speeches.length)];
      } while (nextSpeech == _currentSpeech && _speeches.length > 1);
      _currentSpeech = nextSpeech;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _isPressed = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Partículas/círculos decorativos de fondo con brillos suaves
        Positioned(
          top: 30,
          left: 50,
          child: _buildGlowingBubble(16, AppColors.gradientBgStart.withOpacity(0.2)),
        ),
        Positioned(
          bottom: 40,
          right: 60,
          child: _buildGlowingBubble(24, AppColors.gradientBgEnd.withOpacity(0.15)),
        ),
        Positioned(
          top: 70,
          right: 40,
          child: _buildGlowingBubble(12, Colors.white.withOpacity(0.3)),
        ),

        // 2. Pedestal / Plataforma
        Positioned(
          bottom: 30,
          child: Container(
            width: 150,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.elliptical(150, 20)),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.4),
                  Colors.white.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
        ),

        // 3. Mascota Flotante (Huevo con auras y anillos de órbita)
        Positioned(
          bottom: 38,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Huevo e Interacción
                    GestureDetector(
                      onTap: _onTapMascot,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Aura trasera resplandeciente
                          Container(
                            width: 75,
                            height: 95,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.35),
                                  blurRadius: 25,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),

                          // Anillo orbital rotando
                          Transform.rotate(
                            angle: _rotateAnimation.value,
                            child: CustomPaint(
                              size: const Size(120, 120),
                              painter: OrbitalRingPainter(),
                            ),
                          ),

                          // Huevo de aprendizaje (cuerpo principal)
                          AnimatedScale(
                            scale: _isPressed ? 0.85 : _scaleAnimation.value,
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutBack,
                            child: Container(
                              width: 65,
                              height: 85,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(45),
                                  topRight: Radius.circular(45),
                                  bottomLeft: Radius.circular(35),
                                  bottomRight: Radius.circular(35),
                                ),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF9E7CFF),
                                    Color(0xFFFF8FA3),
                                    Color(0xFF5BA2F4),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.7),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Reflejo de luz en el huevo para darle tridimensionalidad
                                  Positioned(
                                    top: 8,
                                    left: 12,
                                    child: Container(
                                      width: 14,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.35),
                                        borderRadius: const BorderRadius.all(
                                          Radius.elliptical(7, 12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Detalle de carita durmiendo (ojitos y boquita)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 10.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text('◡', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.0)),
                                              SizedBox(width: 10),
                                              Text('◡', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.0)),
                                            ],
                                          ),
                                          SizedBox(height: 2),
                                          Text('o', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.0)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Nombre y estadísticas debajo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.egg_rounded, color: AppColors.primary, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'NV. 1: Huevo Lingui',
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Barra de evolución
                    SizedBox(
                      width: 110,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Evolución',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppColors.onSurfaceMuted,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              Text(
                                '40%',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppColors.primary.withOpacity(0.8),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SizedBox(
                              height: 4,
                              child: LinearProgressIndicator(
                                value: 0.4,
                                backgroundColor: AppColors.border,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
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
            },
          ),
        ),

        // 4. Globo de Diálogo Flotante (Speech Balloon)
        Positioned(
          top: 15,
          child: AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 300),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _currentSpeech,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                      height: 1.3,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -5,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 10,
                      height: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlowingBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

// Pintor del anillo orbital con guiones futuristas
class OrbitalRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Dibujar el anillo de forma elíptica inclinada
    final rect = Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height * 0.35,
    );

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Crear un camino punteado/discontinuo
    final path = Path()..addOval(rect);
    
    // Inclinamos el lienzo un poco para darle perspectiva 3D
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.25); // Inclinación orbital
    canvas.translate(-center.dx, -center.dy);
    
    // Dibujamos con línea punteada manual o dibujando pequeños arcos
    const double dashWidth = 5;
    const double dashSpace = 5;
    
    // Usamos path metrics para cortar en guiones
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

