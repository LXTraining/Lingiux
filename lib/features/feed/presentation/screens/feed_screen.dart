import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../../../vocabulary/presentation/screens/word_detail_screen.dart';
import '../widgets/streak_drawer.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            drawer: const StreakDrawer(),
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
                      Scaffold.of(context).openDrawer();
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
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.home_rounded,
                      size: 52,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    AppStrings.navInicio,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Explora tus tarjetas mnemotécnicas, practica tu pronunciación con Inteligencia Artificial y chatea en tiempo real con otros estudiantes de la comunidad.',
                      style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
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
