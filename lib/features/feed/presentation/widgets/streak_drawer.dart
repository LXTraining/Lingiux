import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class StreakDrawer extends ConsumerWidget {
  const StreakDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        // Racha Principal Card (Coral/Orange Gradient)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B8B), Color(0xFFFF8E53)], // Coral a Orange
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B8B).withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'RACHA ACTUAL',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$streakCount ${streakCount == 1 ? "día" : "días"}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '¡Mantén el fuego encendido! Practica hoy para no perder tu racha.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 12,
                                        height: 1.4,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Fuego animado grande
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text(
                                  '🔥',
                                  style: TextStyle(fontSize: 42),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Rastreador Semanal
                        const Text(
                          'Seguimiento Semanal',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildWeeklyTracker(streakCount),
                        const SizedBox(height: 28),

                        // Sección de Logros
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

  Widget _buildWeeklyTracker(int streakCount) {
    final now = DateTime.now();
    final weekDays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final currentDayIndex = now.weekday - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final diffFromToday = currentDayIndex - index;
        final isCompleted = diffFromToday >= 0 && diffFromToday < streakCount;
        final isToday = index == currentDayIndex;

        return Column(
          children: [
            Text(
              weekDays[index],
              style: TextStyle(
                color: isToday ? AppColors.primary : AppColors.onSurfaceMuted,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? const Color(0xFF4CD9A3).withValues(alpha: 0.15)
                    : isToday
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                border: Border.all(
                  color: isCompleted
                      ? const Color(0xFF4CD9A3)
                      : isToday
                          ? AppColors.primary
                          : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Text('🔥', style: TextStyle(fontSize: 13))
                    : isToday
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      }),
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
}
