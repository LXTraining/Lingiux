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

class ProfileScreen extends ConsumerWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isOwnProfile = userId == null || userId == user?.id;
    final effectiveUserId = userId ?? user?.id;

    final profileAsync = ref.watch(profileFamilyProvider(userId));
    final userCardsAsync = ref.watch(userWordCardsFamilyProvider(userId));
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
                ref.invalidate(profileFamilyProvider(userId));
                ref.invalidate(userWordCardsFamilyProvider(userId));
                try {
                  await ref.read(profileFamilyProvider(userId).future);
                  await ref.read(userWordCardsFamilyProvider(userId).future);
                } catch (_) {}
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- CABECERA ALINEADA A LA IZQUIERDA CON BANDERAS ---
                    const SizedBox(height: 14),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Foto de perfil circular alineada a la izquierda (pulsable para cambiar)
                          GestureDetector(
                            onTap: isOwnProfile ? () => _changeAvatar(context, ref) : null,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 36, // Radio compacto
                                    backgroundColor: AppColors.primary,
                                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl == null || avatarUrl.isEmpty
                                        ? Text(
                                            initials,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Inter',
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                // Indicador online
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: AppColors.online,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 16),

                          // 2. Nickname, estrellas y banderas a la derecha de la foto
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: List.generate(5, (index) => const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber,
                                    size: 14,
                                  )),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    // Bandera nativa de nacimiento (Español/México por defecto)
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: SvgPicture.asset(
                                          profileAsync.value?['native_language'] == 'Inglés' ? 'assets/flags/us.svg' : 'assets/flags/mx.svg',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Icono de transición
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 12,
                                      color: AppColors.onSurfaceMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    // Bandera del idioma que aprende
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: SvgPicture.asset(
                                          targetLanguage == 'Inglés' ? 'assets/flags/us.svg' : 'assets/flags/mx.svg',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // 3. Stats de cartas creadas a la derecha de la fila (estilo Plato)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border, width: 0.5),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  userCardsAsync.when(
                                    data: (cards) => cards.length.toString(),
                                    loading: () => '...',
                                    error: (err, stack) => '0',
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                    'CARTAS',
                                    style: TextStyle(
                                      color: AppColors.onSurfaceMuted,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          email,
                          style: const TextStyle(
                            color: AppColors.onSurfaceMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

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

                    const SizedBox(height: 12),

                    // 4. Botones de acción horizontal compactos (altura 38)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          if (isOwnProfile) ...[
                            // Ajustes (Engranaje)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                              },
                              child: Container(
                                height: 38,
                                width: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border, width: 0.5),
                                ),
                                child: const Icon(
                                  Icons.settings_outlined,
                                  color: AppColors.onSurface,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Botón de Editar Perfil
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                },
                                icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                                label: const Text(
                                  'EDITAR PERFIL',
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
                            const SizedBox(width: 8),
                            // Compartir
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                              },
                              child: Container(
                                height: 38,
                                width: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border, width: 0.5),
                                ),
                                child: const Icon(
                                  Icons.share_rounded,
                                  color: AppColors.onSurface,
                                  size: 18,
                                ),
                              ),
                            ),
                          ] else ...[
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
                                      userId!,
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
                        ],
                      ),
                    ),

                  // Pestañas de Selección de Vista (Grid de publicaciones activo)
                  const SizedBox(height: 20),
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.border, width: 0.5),
                        bottom: BorderSide(color: AppColors.border, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            child: const Icon(
                              Icons.grid_on_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: const Icon(
                              Icons.bookmark_border_rounded,
                              color: AppColors.onSurfaceMuted,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cuadrícula de 3 columnas de las cartas del usuario
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: userCardsAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'Error al cargar tus cartas: $err',
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ),
                      data: (cards) {
                        if (cards.isEmpty) {
                          return const Center(
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
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            childAspectRatio: 2 / 3,
                          ),
                          itemCount: cards.length,
                          itemBuilder: (context, index) {
                            final card = cards[index];
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
                              child: _MiniWordCard(
                                wordCard: card,
                                gradientIndex: index,
                              ),
                            );
                          },
                        );
                      },
                    ),
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
