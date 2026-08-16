import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class StreakDrawer extends ConsumerStatefulWidget {
  const StreakDrawer({super.key});

  @override
  ConsumerState<StreakDrawer> createState() => _StreakDrawerState();
}

class _StreakDrawerState extends ConsumerState<StreakDrawer> {
  bool _isGiftClaimed = false;

  Widget _buildGiftChestCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)], // Indigo/Purple gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cofre físico grande
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Text(
              '🎁',
              style: TextStyle(fontSize: 44),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '¡Cofre Sorpresa!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'De Ana Smith para ti',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          if (!_isGiftClaimed)
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _isGiftClaimed = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎁 ¡Gemas reclamadas! +50 gemas agregadas.'),
                    backgroundColor: Color(0xFFFF6B8B),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD000), // Gold button
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_open_rounded, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'ABRIR COFRE (+50 💎)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF4CD9A3), size: 18),
                  SizedBox(width: 8),
                  Text(
                    '¡Abierto! +50 Gemas 💎',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLessonCommentCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Avatar de Sophia
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF4F46E5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'SO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sophia',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Hace 10 min • Lección "Básico 1"',
                      style: TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 10,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              // Globo de Opiniones Eco
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('💬', style: TextStyle(fontSize: 10)),
                    SizedBox(width: 4),
                    Text(
                      'Eco',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Comentario textual en forma de burbuja
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '“¡Me encantó la lección! Es súper interactiva y los ejemplos de audio ayudan muchísimo a pronunciar.”',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.4,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneTile({
    required BuildContext context,
    required String title,
    required String description,
    required int daysNeeded,
    required int currentStreak,
    required String emoji,
  }) {
    final isUnlocked = currentStreak >= daysNeeded;
    final progress = (currentStreak / daysNeeded).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isUnlocked
                  ? Text(emoji, style: const TextStyle(fontSize: 22))
                  : const Icon(Icons.lock_outline_rounded, color: AppColors.onSurfaceMuted, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isUnlocked ? AppColors.onSurface : AppColors.onSurfaceMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 11,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUnlocked ? const Color(0xFF4CD9A3) : AppColors.primary,
                    ),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          isUnlocked
              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4CD9A3), size: 20)
              : Text(
                  '$currentStreak/$daysNeeded d',
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Drawer(
      backgroundColor: AppColors.background,
      elevation: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'No se pudieron cargar los datos de racha.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.onSurface, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(profileProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          data: (profile) {
            final fullName = profile?['full_name'] ?? 'Usuario de Lingiux';
            final avatarUrl = profile?['avatar_url'] as String?;
            final targetLanguage = profile?['target_language'] ?? 'Inglés';
            final streakCount = profile?['streak_count'] as int? ?? 0;

            final initials = fullName.trim().isNotEmpty
                ? fullName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                : 'LX';

            final isEnglish = targetLanguage == 'Inglés' || targetLanguage == 'English';
            final flagAsset = isEnglish ? 'assets/flags/us.svg' : 'assets/flags/mx.svg';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header del Perfil
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 16, top: 20, bottom: 12),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primary,
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Nombre e idioma objetivo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text(
                                  'Aprendiendo: ',
                                  style: TextStyle(
                                    color: AppColors.onSurfaceMuted,
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                Text(
                                  targetLanguage,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 0.5),
                                  ),
                                  child: ClipOval(
                                    child: SvgPicture.asset(
                                      flagAsset,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Botón para cerrar Drawer
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.onSurfaceMuted, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const Divider(indent: 20, endIndent: 20),

                // 2. Contenido Scrollable
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sección de Novedades y Regalos
                        const Text(
                          'Novedades y Regalos',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // 1. Cofre de Regalo tal cual
                        _buildGiftChestCard(context),

                        const SizedBox(height: 16),

                        // 2. Comentario de Sophia tal cual
                        _buildLessonCommentCard(context),

                        const SizedBox(height: 24),

                        // Sección de Logros (que sigue)
                        const Text(
                          'Logros de Racha',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildMilestoneTile(
                          context: context,
                          title: 'Iniciador de Racha',
                          description: 'Completa 3 días seguidos',
                          daysNeeded: 3,
                          currentStreak: streakCount,
                          emoji: '🥉',
                        ),
                        _buildMilestoneTile(
                          context: context,
                          title: 'Estudiante Constante',
                          description: 'Completa 7 días seguidos',
                          daysNeeded: 7,
                          currentStreak: streakCount,
                          emoji: '🥈',
                        ),
                        _buildMilestoneTile(
                          context: context,
                          title: 'Mente Imparable',
                          description: 'Completa 14 días seguidos',
                          daysNeeded: 14,
                          currentStreak: streakCount,
                          emoji: '🥇',
                        ),
                        _buildMilestoneTile(
                          context: context,
                          title: 'Leyenda de Lingiux',
                          description: 'Completa 30 días seguidos',
                          daysNeeded: 30,
                          currentStreak: streakCount,
                          emoji: '👑',
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // 3. Botón inferior de acción
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '¡A PRACTICAR AHORA!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.8,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
