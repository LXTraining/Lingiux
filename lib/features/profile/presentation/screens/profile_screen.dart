import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../vocabulary/presentation/providers/vocabulary_provider.dart';
import '../../../vocabulary/presentation/screens/word_detail_screen.dart';
import '../../../vocabulary/domain/models/word_card_model.dart';
import '../../../chat/presentation/screens/chat_detail_screen.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../chat/domain/entities/chat_entity.dart';
import '../providers/profile_provider.dart';
import 'settings_screen.dart';
import '../../../lessons/presentation/providers/lessons_provider.dart';
import '../../../lessons/domain/models/lesson_model.dart';

final userBioProvider = FutureProvider.family.autoDispose<String, String>((ref, userId) async {
  final prefs = await SharedPreferences.getInstance();
  final local = prefs.getString('user_bio_$userId');
  if (local != null && local.isNotEmpty) {
    return local;
  }
  
  try {
    final profile = await ref.watch(profileFamilyProvider(userId).future);
    final dbBio = profile?['bio'] as String?;
    if (dbBio != null && dbBio.isNotEmpty) {
      return dbBio;
    }
  } catch (_) {}
  
  return '¡Hola! Estoy aprendiendo idiomas en Lingiux 🚀';
});

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _activeTabIndex = 0; // 0: Mis Cartas, 1: Mis Lecciones, 2: Mi Progreso
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _activeTabIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getFlagPath(String lang) {
    final lower = lang.toLowerCase();
    if (lower == 'inglés' || lower == 'english' || lower == 'en') {
      return 'assets/flags/us.svg';
    } else if (lower == 'francés' || lower == 'frances' || lower == 'fr' || lower == 'french') {
      return 'assets/flags/fr.svg';
    } else if (lower == 'alemán' || lower == 'aleman' || lower == 'de' || lower == 'german') {
      return 'assets/flags/de.svg';
    } else if (lower == 'italiano' || lower == 'it' || lower == 'italian') {
      return 'assets/flags/it.svg';
    } else if (lower == 'portugués' || lower == 'portugues' || lower == 'pt' || lower == 'portuguese') {
      return 'assets/flags/br.svg';
    }
    return 'assets/flags/mx.svg';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isOwnProfile = widget.userId == null || widget.userId == user?.id;
    final effectiveUserId = widget.userId ?? user?.id;

    final profileAsync = ref.watch(profileFamilyProvider(widget.userId));
    final userCardsAsync = ref.watch(userWordCardsFamilyProvider(widget.userId));
    final resolvedCardsAsync = ref.watch(resolvedCardsFamilyProvider(widget.userId));
    final bioAsync = ref.watch(userBioProvider(effectiveUserId ?? ''));

    // Print de depuración para saber si las cartas se cargaron bien
    userCardsAsync.when(
      data: (cards) => debugPrint('ProfileScreen debug: ${cards.length} cards loaded: ${cards.map((c) => c.word).toList()}'),
      loading: () => debugPrint('ProfileScreen debug: loading user cards...'),
      error: (err, stack) => debugPrint('ProfileScreen debug error: $err'),
    );

    final email = isOwnProfile ? (user?.email ?? '') : '';
    final fullName = profileAsync.value?['full_name'] ?? (isOwnProfile ? (user?.userMetadata?['full_name'] ?? 'Usuario de Lingiux') : 'Usuario de Lingiux');
    final avatarUrl = profileAsync.value?['avatar_url'] ?? (isOwnProfile ? (user?.userMetadata?['avatar_url'] as String?) : null);
    final targetLanguage = profileAsync.value?['target_language'] ?? 'Inglés';

    final initials = fullName.trim().isNotEmpty
        ? fullName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'LX';

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
          if (Navigator.canPop(context)) {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          }
        }
      },
      child: Container(
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
              title: Text(
                fullName.toLowerCase().replaceAll(' ', '_'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Inter',
                ),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              actions: [
                if (isOwnProfile)
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppColors.onSurface),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
              ],
            ),
            body: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                ref.invalidate(profileFamilyProvider(widget.userId));
                ref.invalidate(userWordCardsFamilyProvider(widget.userId));
                ref.invalidate(resolvedCardsFamilyProvider(widget.userId));
                try {
                  await ref.read(profileFamilyProvider(widget.userId).future);
                  await ref.read(userWordCardsFamilyProvider(widget.userId).future);
                  await ref.read(resolvedCardsFamilyProvider(widget.userId).future);
                } catch (_) {}
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- DISEÑO PREMIUM DE CABECERA: PIRÁMIDE INVERTIDA COMPACTA ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Column(
                        children: [
                          // 1. Avatar centrado en la parte superior
                          GestureDetector(
                            onTap: isOwnProfile ? () => _changeAvatar(context, ref) : null,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Anillo de brillo/destellos discreto
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: [
                                        AppColors.primary.withValues(alpha: 0.03),
                                        Colors.amber.withValues(alpha: 0.12),
                                        AppColors.primary.withValues(alpha: 0.03),
                                      ],
                                    ),
                                  ),
                                ),
                                // Avatar compacto (radio 30)
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundColor: AppColors.primary,
                                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl == null || avatarUrl.isEmpty
                                        ? Text(
                                            initials,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Inter',
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                // Indicador online compacto
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.online,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 6),

                          // Fila 2: Rango (Extremo Izq) | Nombre/Estrellas/Banderas (Centro) | Cartas (Extremo Der)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Stat 1: Extremo Izquierdo (Rango / Liga)
                              Expanded(
                                child: _buildHeaderStatCard(
                                  title: 'LEYENDA',
                                  subtitle: 'RANGO',
                                  icon: Icons.emoji_events_rounded,
                                  iconColor: Colors.amber,
                                ),
                              ),
                              
                              // Centro: Nombre, Estrellas y Banderas
                              Container(
                                width: 140,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      fullName,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.onSurface,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(5, (index) => const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 11,
                                      )),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Bandera Nativa
                                        Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.2),
                                          ),
                                          child: ClipOval(
                                            child: SvgPicture.asset(
                                              _getFlagPath(profileAsync.value?['native_language'] ?? ''),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                                          child: Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 9,
                                            color: AppColors.onSurfaceMuted,
                                          ),
                                        ),
                                        // Bandera Destino
                                        Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.2),
                                          ),
                                          child: ClipOval(
                                            child: SvgPicture.asset(
                                              _getFlagPath(targetLanguage),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Stat 2: Extremo Derecho (Cartas Creadas)
                              Expanded(
                                child: _buildHeaderStatCard(
                                  title: userCardsAsync.when(
                                    data: (cards) => cards.length.toString(),
                                    loading: () => '...',
                                    error: (err, stack) => '0',
                                  ),
                                  subtitle: 'CARTAS',
                                  icon: Icons.auto_awesome_motion_rounded,
                                  iconColor: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 6),
                          
                          // Fila 3: Racha (Medio Izq) | Seguidores (Medio Der) - Escalón más centrado
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                // Stat 3: Racha (Fuego)
                                Expanded(
                                  child: _buildHeaderStatCard(
                                    title: (profileAsync.value?['streak_count'] ?? 0).toString(),
                                    subtitle: 'RACHA',
                                    icon: Icons.local_fire_department_rounded,
                                    iconColor: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Stat 4: Seguidores (Grupo)
                                Expanded(
                                  child: _buildHeaderStatCard(
                                    title: '45',
                                    subtitle: 'SEGUIDORES',
                                    icon: Icons.group_rounded,
                                    iconColor: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 6),
                          
                          // Fila 4: Nacionalidad (Centro Abajo) - Último escalón centrado
                          Container(
                            width: 120,
                            child: _buildNationalityStatCard(
                              profileAsync.value?['nationality'] as String? ?? 'México',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Cuadro de estado/descripción (mensaje configurable por el usuario)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GestureDetector(
                        onTap: isOwnProfile
                            ? () {
                                final bioText = bioAsync.value ?? '¡Hola! Estoy aprendiendo idiomas en Lingiux 🚀';
                                _editBio(context, ref, bioText, effectiveUserId ?? '');
                              }
                            : null,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.surfaceVariant.withValues(alpha: 0.3),
                                AppColors.surfaceVariant.withValues(alpha: 0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.7),
                              width: 0.8,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  bioAsync.when(
                                    data: (bio) => bio,
                                    loading: () => 'Cargando descripción...',
                                    error: (err, stack) => '¡Hola! Estoy aprendiendo idiomas en Lingiux 🚀',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                              if (isOwnProfile)
                                const Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Icon(
                                    Icons.mode_edit_outline_rounded,
                                    size: 13,
                                    color: AppColors.onSurfaceMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 4. Botones de acción horizontal compactos (Solo para perfiles ajenos)
                    if (!isOwnProfile) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            // Mensaje directo (Perfil ajeno)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  final currentUserId = ref.read(authProvider).user?.id;
                                  if (currentUserId == null) return;

                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: CircularProgressIndicator(color: AppColors.primary),
                                    ),
                                  );

                                  try {
                                    final chatService = ref.read(chatServiceProvider);
                                    final convId = await chatService.getOrCreateConversation(
                                      currentUserId,
                                      widget.userId!,
                                    );

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      
                                      final initials = fullName.trim().isNotEmpty
                                          ? fullName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                                          : 'LX';
                                          
                                      final chatEntity = ChatEntity(
                                        id: convId,
                                        name: fullName,
                                        initials: initials,
                                        avatarColorIndex: fullName.hashCode.abs(),
                                        lastMessage: 'Conversación iniciada',
                                        lastMessageTime: DateTime.now(),
                                        unreadCount: 0,
                                        isOnline: false,
                                        messages: const [],
                                        avatarUrl: avatarUrl,
                                      );

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatDetailScreen(chat: chatEntity),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error al iniciar conversación: $e')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
                                label: const Text(
                                  'ENVIAR MENSAJE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  elevation: 0,
                                  minimumSize: const Size.fromHeight(38),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                  // Pestañas de Selección de Vista (Cápsula deslizable de 3 pestañas premium)
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! < -200) {
                            // Deslizar hacia la izquierda (avanzar tab)
                            if (_activeTabIndex < 2) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _activeTabIndex++;
                              });
                              if (_pageController.hasClients) {
                                _pageController.animateToPage(
                                  _activeTabIndex,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              }
                            }
                          } else if (details.primaryVelocity! > 200) {
                            // Deslizar hacia la derecha (retroceder tab)
                            if (_activeTabIndex > 0) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _activeTabIndex--;
                              });
                              if (_pageController.hasClients) {
                                _pageController.animateToPage(
                                  _activeTabIndex,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              }
                            }
                          }
                        }
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final totalWidth = constraints.maxWidth;
                            final pillWidth = totalWidth / 3 - 2;
                            final leftOffset = _activeTabIndex == 0 
                                ? 2.0 
                                : (_activeTabIndex == 1 ? (totalWidth / 3) : (totalWidth * 2 / 3));
                            
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // Fondo de la pestaña activa (Cápsula deslizable)
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  left: leftOffset,
                                  top: 2,
                                  bottom: 2,
                                  width: pillWidth,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.35),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Botones de las pestañas
                                Row(
                                  children: [
                                    // Tab 0: Mis Cartas
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _activeTabIndex = 0;
                                          });
                                          if (_pageController.hasClients) {
                                            _pageController.animateToPage(
                                              0,
                                              duration: const Duration(milliseconds: 250),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                        },
                                        child: Container(
                                          color: Colors.transparent,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.collections_bookmark_rounded,
                                                color: _activeTabIndex == 0 ? Colors.white : AppColors.onSurfaceMuted,
                                                size: 15,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Mis Cartas',
                                                style: TextStyle(
                                                  color: _activeTabIndex == 0 ? Colors.white : AppColors.onSurfaceMuted,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Inter',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Tab 1: Mis Lecciones
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _activeTabIndex = 1;
                                          });
                                          if (_pageController.hasClients) {
                                            _pageController.animateToPage(
                                              1,
                                              duration: const Duration(milliseconds: 250),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                        },
                                        child: Container(
                                          color: Colors.transparent,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.map_rounded,
                                                color: _activeTabIndex == 1 ? Colors.white : AppColors.onSurfaceMuted,
                                                size: 15,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Mis Lecciones',
                                                style: TextStyle(
                                                  color: _activeTabIndex == 1 ? Colors.white : AppColors.onSurfaceMuted,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Inter',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Tab 2: Mi Progreso
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _activeTabIndex = 2;
                                          });
                                          if (_pageController.hasClients) {
                                            _pageController.animateToPage(
                                              2,
                                              duration: const Duration(milliseconds: 250),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                        },
                                        child: Container(
                                          color: Colors.transparent,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.leaderboard_rounded,
                                                color: _activeTabIndex == 2 ? Colors.white : AppColors.onSurfaceMuted,
                                                size: 15,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Progreso',
                                                style: TextStyle(
                                                  color: _activeTabIndex == 2 ? Colors.white : AppColors.onSurfaceMuted,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Inter',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Contenido Condicional de la pestaña seleccionada con PageView y altura dinámica
                  userCardsAsync.when(
                    loading: () => const SizedBox(),
                    error: (err, stack) => const SizedBox(),
                    data: (userCards) {
                      return resolvedCardsAsync.when(
                        loading: () => const SizedBox(),
                        error: (err, stack) => const SizedBox(),
                        data: (resolvedCards) {
                          // Calcular altura de la cuadrícula
                          final screenWidth = MediaQuery.of(context).size.width;
                          final cardWidth = (screenWidth - 28) / 3;
                          final cardHeight = cardWidth * 1.5;
                          final rows = (userCards.length / 3).ceil();
                          final gridHeight = userCards.isEmpty
                              ? 200.0
                              : (rows * (cardHeight + 6)) + 24.0;

                          // Calcular altura de estadísticas
                          final Set<String> languages = {};
                          for (final c in userCards) {
                            if (c.language != null && c.language!.isNotEmpty) {
                              languages.add(c.language!.toUpperCase());
                            }
                          }
                          for (final rc in resolvedCards) {
                            final String? lang = rc['language'] as String?;
                            if (lang != null && lang.isNotEmpty) {
                              languages.add(lang.toUpperCase());
                            }
                          }
                          if (languages.isEmpty) {
                            languages.add('INGLÉS');
                          }
                          final languageList = languages.toList()..sort();
                           final statsHeight = (languageList.length * 80.0) + 60.0;
  
                           final userLessonsAsync = ref.watch(userLessonsProvider(effectiveUserId ?? ''));
                           final userLessons = userLessonsAsync.value ?? [];
                           const double rowHeight = 150.0;
                           final lessonsHeight = userLessons.isEmpty ? 200.0 : (userLessons.length * rowHeight) + 40.0;
  
                           final contentHeight = _activeTabIndex == 0 
                               ? gridHeight 
                               : (_activeTabIndex == 1 ? lessonsHeight : statsHeight);
  
                           return AnimatedContainer(
                             duration: const Duration(milliseconds: 200),
                             curve: Curves.easeInOut,
                             height: contentHeight,
                             child: PageView(
                               controller: _pageController,
                               onPageChanged: (index) {
                                 HapticFeedback.selectionClick();
                                 setState(() {
                                   _activeTabIndex = index;
                                 });
                               },
                               children: [
                                 // Página 0: Grid de Cartas Creadas
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: userCards.isEmpty
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(48.0),
                                            child: Column(
                                              children: [
                                                Icon(Icons.style_outlined, size: 48, color: AppColors.onSurfaceMuted),
                                                SizedBox(height: 12),
                                                Text(
                                                  'No has creado ninguna tarjeta aún.',
                                                  style: TextStyle(color: AppColors.onSurfaceMuted),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            crossAxisSpacing: 6,
                                            mainAxisSpacing: 6,
                                            childAspectRatio: 2 / 3,
                                          ),
                                          itemCount: userCards.length,
                                          itemBuilder: (context, index) {
                                            final card = userCards[index];
                                            return GestureDetector(
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => WordDetailScreen(selectedWord: card.word),
                                                  ),
                                                );
                                              },
                                              child: Stack(
                                                children: [
                                                  _MiniWordCard(
                                                    wordCard: card,
                                                    gradientIndex: index,
                                                  ),
                                                  Positioned(
                                                    top: 6,
                                                    right: 6,
                                                    child: Container(
                                                      width: 18,
                                                      height: 18,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: Colors.white, width: 1.5),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withValues(alpha: 0.15),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: ClipOval(
                                                        child: SvgPicture.asset(
                                                          _getFlagPath(card.language ?? 'Inglés'),
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                                // Página 1: Caminito de Lecciones Creadas
                                _buildLessonsPathTab(context, userLessons, fullName, avatarUrl),

                                // Página 2: Estadísticas por Idioma (Mi Progreso)
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'STATS',
                                        style: TextStyle(
                                          color: AppColors.onSurfaceMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: languageList.length,
                                        separatorBuilder: (context, index) => const Divider(
                                          color: AppColors.border,
                                          height: 24,
                                          thickness: 0.5,
                                        ),
                                        itemBuilder: (context, index) {
                                          final lang = languageList[index];
                                          final resolvedCount = resolvedCards
                                              .where((rc) => rc['language']?.toLowerCase() == lang.toLowerCase())
                                              .length;
                                          final totalCount = userCards
                                              .where((uc) => uc.language?.toLowerCase() == lang.toLowerCase())
                                              .length;

                                          final int level = (resolvedCount / 3).floor() + 1;
                                          final double progress = (resolvedCount % 3) / 3.0;

                                          String rankTitle = 'Novato';
                                          if (level == 2) rankTitle = 'Aprendiz';
                                          if (level == 3) rankTitle = 'Avanzado';
                                          if (level == 4) rankTitle = 'Experto';
                                          if (level >= 5) rankTitle = 'Leyenda';

                                          return Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Container(
                                                    width: 44,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: Colors.white, width: 2),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.1),
                                                          blurRadius: 6,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: ClipOval(
                                                      child: SvgPicture.asset(
                                                        _getFlagPath(lang),
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: -2,
                                                    right: -2,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(3),
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFF2563EB),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Text(
                                                        level.toString(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          lang,
                                                          style: const TextStyle(
                                                            color: AppColors.onSurface,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.bold,
                                                            fontFamily: 'Inter',
                                                          ),
                                                        ),
                                                        Text(
                                                          'Nivel $level',
                                                          style: const TextStyle(
                                                            color: AppColors.onSurface,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            fontFamily: 'Inter',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: LinearProgressIndicator(
                                                        value: progress,
                                                        color: const Color(0xFF22C55E),
                                                        backgroundColor: AppColors.border.withValues(alpha: 0.3),
                                                        minHeight: 8,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          rankTitle,
                                                          style: const TextStyle(
                                                            color: AppColors.onSurfaceMuted,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                        Text(
                                                          'Resueltas: $resolvedCount  Creadas: $totalCount',
                                                          style: const TextStyle(
                                                            color: AppColors.onSurfaceMuted,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
      ),
    ),
    );
  }

  Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
    try {
      HapticFeedback.mediumImpact();
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );
      if (file == null) return;

      // Mostrar diálogo de carga
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      final bytes = await file.readAsBytes();
      final supabase = ref.read(supabaseClientProvider);
      final user = ref.read(authProvider).user;
      if (user == null) {
        if (context.mounted) Navigator.pop(context);
        return;
      }

      final fileExt = file.name.split('.').last;
      final path = 'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // 1. Subir la foto al storage público de Supabase
      await supabase.storage.from('word-images').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$fileExt'),
      );

      // 2. Obtener URL pública
      final avatarUrl = supabase.storage.from('word-images').getPublicUrl(path);

      // 3. Actualizar la tabla profiles de Supabase
      await supabase.from('profiles').update({'avatar_url': avatarUrl}).eq('id', user.id);

      // 4. Quitar loader
      if (context.mounted) Navigator.pop(context);

      // 5. Invalidad proveedores para refrescar
      ref.invalidate(profileProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil actualizada con éxito'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      // Quitar loader si sigue en pantalla
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar la foto de perfil: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _editBio(BuildContext context, WidgetRef ref, String currentBio, String effectiveUserId) {
    final textController = TextEditingController(text: currentBio);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Editar Estado / Descripción',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: textController,
            maxLength: 100,
            maxLines: 3,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'Escribe tu descripción...',
              hintStyle: const TextStyle(color: AppColors.onSurfaceMuted),
              counterStyle: const TextStyle(color: AppColors.onSurfaceMuted),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.border, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: AppColors.onSurfaceMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newBio = textController.text.trim();
                Navigator.pop(context);
                
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_bio_$effectiveUserId', newBio);
                  
                  final supabase = ref.read(supabaseClientProvider);
                  await supabase.from('profiles').update({'bio': newBio}).eq('id', effectiveUserId);
                } catch (e) {
                  debugPrint('Error guardando bio: $e');
                }
                
                ref.invalidate(userBioProvider(effectiveUserId));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('GUARDAR', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _getNationalityFlagAsset(String nationality) {
    switch (nationality.toUpperCase()) {
      case 'MÉXICO':
      case 'MEXICO':
        return 'assets/flags/mx.svg';
      case 'ESTADOS UNIDOS':
      case 'USA':
      case 'UNITED STATES':
        return 'assets/flags/us.svg';
      case 'ALEMANIA':
      case 'GERMANY':
        return 'assets/flags/de.svg';
      case 'FRANCIA':
      case 'FRANCE':
        return 'assets/flags/fr.svg';
      case 'ITALIA':
      case 'ITALY':
        return 'assets/flags/it.svg';
      case 'BRASIL':
      case 'BRAZIL':
        return 'assets/flags/br.svg';
      default:
        return '';
    }
  }

  Widget _buildNationalityStatCard(String nationality) {
    final flagAsset = _getNationalityFlagAsset(nationality);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipOval(
            child: flagAsset.isNotEmpty
                ? SvgPicture.asset(
                    flagAsset,
                    fit: BoxFit.cover,
                  )
                : const Icon(Icons.flag_rounded, size: 10, color: AppColors.onSurfaceMuted),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          nationality.toUpperCase(),
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 1),
        const Text(
          'NACIONALIDAD',
          style: TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 7,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderStatCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 12,
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 7,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLessonsPathTab(
    BuildContext context,
    List<LessonModel> lessons,
    String creatorName,
    String? creatorAvatar,
  ) {
    if (lessons.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 48, color: AppColors.onSurfaceMuted),
              SizedBox(height: 12),
              Text(
                'No has creado ninguna lección aún.',
                style: TextStyle(color: AppColors.onSurfaceMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    const double rowHeight = 150.0;
    const double nodeSize = 80.0;
    const double cardHeight = 76.0;

    // Camino ondulado idéntico al feed
    final xFractions = [0.25, 0.65, 0.35, 0.70, 0.40, 0.65];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final totalHeight = lessons.length * rowHeight + 40.0;

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(), // Scroll gestionado por el Scaffold padre
          child: Stack(
            children: [
              // 1. Camino dibujado con CustomPaint
              SizedBox(
                width: width,
                height: totalHeight,
                child: CustomPaint(
                  painter: _ProfilePathPainter(
                    xFractions: xFractions,
                    rowHeight: rowHeight,
                    itemCount: lessons.length,
                  ),
                ),
              ),

              // 2. Elementos del camino
              SizedBox(
                width: width,
                height: totalHeight,
                child: Stack(
                  children: [
                    for (int index = 0; index < lessons.length; index++) ...[
                      // Tarjeta de la lección
                      Positioned(
                        top: (index * rowHeight + rowHeight / 2) - cardHeight / 2,
                        left: (xFractions[index % xFractions.length] < 0.5)
                            ? (width * xFractions[index % xFractions.length]) + nodeSize / 2 + 10
                            : 20,
                        right: (xFractions[index % xFractions.length] < 0.5)
                            ? 20
                            : (width - (width * xFractions[index % xFractions.length])) + nodeSize / 2 + 10,
                        child: _buildProfileLessonCard(
                          context,
                          lessons[index],
                          (xFractions[index % xFractions.length] < 0.5),
                          cardHeight,
                          creatorName,
                        ),
                      ),
                      // Nodo interactivo de la lección
                      Positioned(
                        left: (width * xFractions[index % xFractions.length]) - nodeSize / 2,
                        top: (index * rowHeight + rowHeight / 2) - nodeSize / 2,
                        child: _ProfileLessonNode(
                          lesson: lessons[index],
                          size: nodeSize,
                          gradientIndex: index,
                          onTap: () => _showProfileLessonDetailsBottomSheet(context, lessons[index], creatorName, creatorAvatar),
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
  }

  Widget _buildProfileLessonCard(
    BuildContext context,
    LessonModel lesson,
    bool isLeft,
    double cardHeight,
    String creatorName,
  ) {
    return Container(
      height: cardHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            lesson.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Por $creatorName',
            style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileLessonDetailsBottomSheet(
    BuildContext context,
    LessonModel lesson,
    String creatorName,
    String? creatorAvatar,
  ) {
    HapticFeedback.mediumImpact();
    final gradients = [
      [const Color(0xFF815BF5), const Color(0xFF5A45FF)],
      [const Color(0xFFFF6B8B), const Color(0xFFFF8E53)],
      [const Color(0xFFA258F5), const Color(0xFFF558C9)],
      [const Color(0xFF4FA4F4), const Color(0xFF4CD9A3)],
    ];
    final colorIndex = lesson.title.hashCode.abs() % gradients.length;
    final gradient = gradients[colorIndex];

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
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.map_rounded,
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
                              lesson.language,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.border.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                lesson.difficulty,
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurfaceMuted,
                                ),
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
                        const SizedBox(height: 4),
                        Text(
                          'Por $creatorName',
                          style: const TextStyle(
                            color: AppColors.onSurfaceMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (lesson.description != null && lesson.description!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  lesson.description!,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('${lesson.exercises.length}', 'Ejercicios'),
                  _buildStatItem('${lesson.cardIds.length}', 'Semillas'),
                ],
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🎮 ¡Próximamente podrás jugar tus propias lecciones! Estamos preparando el motor de juegos.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: gradient[0],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'PROBAR LECCIÓN',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ProfilePathPainter extends CustomPainter {
  final List<double> xFractions;
  final double rowHeight;
  final int itemCount;

  _ProfilePathPainter({
    required this.xFractions,
    required this.rowHeight,
    required this.itemCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (itemCount == 0) return;

    final path = Path();
    double startX = size.width * xFractions[0];
    double startY = rowHeight / 2;

    path.moveTo(startX, startY);

    for (int i = 1; i < itemCount; i++) {
      double endX = size.width * xFractions[i % xFractions.length];
      double endY = i * rowHeight + rowHeight / 2;

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
      ..color = AppColors.border.withValues(alpha: 0.3)
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
  bool shouldRepaint(covariant _ProfilePathPainter oldDelegate) => false;
}

class _ProfileLessonNode extends StatefulWidget {
  final LessonModel lesson;
  final double size;
  final int gradientIndex;
  final VoidCallback onTap;

  const _ProfileLessonNode({
    required this.lesson,
    required this.size,
    required this.gradientIndex,
    required this.onTap,
  });

  @override
  State<_ProfileLessonNode> createState() => _ProfileLessonNodeState();
}

class _ProfileLessonNodeState extends State<_ProfileLessonNode> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    final gradients = [
      [const Color(0xFF815BF5), const Color(0xFF5A45FF)],
      [const Color(0xFFFF6B8B), const Color(0xFFFF8E53)],
      [const Color(0xFFA258F5), const Color(0xFFF558C9)],
      [const Color(0xFF4FA4F4), const Color(0xFF4CD9A3)],
    ];
    final colors = gradients[widget.gradientIndex % gradients.length];

    final depthColor = Color.alphaBlend(Colors.black.withValues(alpha: 0.25), colors[1]);

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
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
                        boxShadow: [
                          if (!_isPressed)
                            BoxShadow(
                              color: colors[0].withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _getLanguageFlag(widget.lesson.language),
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLanguageFlag(String language) {
    switch (language.toLowerCase()) {
      case 'inglés':
      case 'ingles':
      case 'english':
        return '🇺🇸';
      case 'alemán':
      case 'aleman':
      case 'german':
        return '🇩🇪';
      case 'francés':
      case 'frances':
      case 'french':
        return '🇫🇷';
      case 'italiano':
      case 'italian':
        return '🇮🇹';
      case 'portugués':
      case 'portugues':
      case 'portuguese':
        return '🇧🇷';
      default:
        return '🌐';
    }
  }
}



class _MiniWordCard extends StatelessWidget {
  final WordCardModel wordCard;
  final int gradientIndex;

  const _MiniWordCard({required this.wordCard, required this.gradientIndex});

  static const List<List<Color>> _gradients = [
    [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    [Color(0xFF0284C7), Color(0xFF6366F1)],
    [Color(0xFF059669), Color(0xFF0284C7)],
    [Color(0xFFD97706), Color(0xFFDC2626)],
    [Color(0xFFDB2777), Color(0xFF7C3AED)],
    [Color(0xFF0D9488), Color(0xFF2563EB)],
    [Color(0xFF7C3AED), Color(0xFFDB2777)],
    [Color(0xFF1D4ED8), Color(0xFF059669)],
  ];

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[gradientIndex % _gradients.length];

    // Contenido base de la tarjeta a escala 300x450
    final cardWidget = Container(
      width: 300,
      height: 450,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          // Fondo decorativo abstracto
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fila superior: categoría y volumen
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (wordCard.category ?? 'VOCABULARY').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    if (wordCard.audioUrl != null && wordCard.audioUrl!.isNotEmpty)
                      Icon(
                        Icons.volume_up_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Palabra
                Text(
                  wordCard.word,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),

                // Fonética
                Text(
                  wordCard.phonetic,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),

                // Imagen
                Center(
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: wordCard.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.white.withValues(alpha: 0.1)),
                        errorWidget: (context, url, err) => Container(
                          color: Colors.white.withValues(alpha: 0.1),
                          child: const Icon(Icons.image_not_supported_outlined, color: Colors.white70, size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Separador
                Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 10),

                // Definición
                Expanded(
                  child: Center(
                    child: Text(
                      wordCard.definition,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
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

    // Escalar la tarjeta con FittedBox
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FittedBox(
          fit: BoxFit.contain,
          child: cardWidget,
        ),
      ),
    );
  }
}

class ProfileErrorScreen extends StatelessWidget {
  const ProfileErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ocurrió un error',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No se pudo encontrar el perfil de este creador.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Volver',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
