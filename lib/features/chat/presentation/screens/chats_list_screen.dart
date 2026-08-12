import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/study_group.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_detail_screen.dart';
import 'group_detail_screen.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/utils/formatters.dart';

class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key});

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  int _activeSegment = 0; // 0 = Mensajes, 1 = Grupos
  final Set<String> _cachedAvatarUrls = {};

  void _showCreateGroupModal(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateGroupSheet(),
    );
  }

  final List<Map<String, dynamic>> _mockPracticedCards = const [
    {
      'friendName': 'Sebas',
      'friendAvatar': null,
      'word': 'Serendipity',
      'gradient': [Color(0xFF7C3AED), Color(0xFF4F46E5)],
      'avatarColorIndex': 0,
    },
    {
      'friendName': 'Pepito',
      'friendAvatar': null,
      'word': 'Mellifluous',
      'gradient': [Color(0xFFFF6B8B), Color(0xFFFF8E53)],
      'avatarColorIndex': 1,
    },
    {
      'friendName': 'Emma',
      'friendAvatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
      'word': 'Ephemeral',
      'gradient': [Color(0xFF4FA4F4), Color(0xFF4CD9A3)],
      'avatarColorIndex': 2,
    },
    {
      'friendName': 'Carlos',
      'friendAvatar': null,
      'word': 'Luminous',
      'gradient': [Color(0xFFA258F5), Color(0xFFF558C9)],
      'avatarColorIndex': 3,
    },
    {
      'friendName': 'Ana',
      'friendAvatar': null,
      'word': 'Resilience',
      'gradient': [Color(0xFF0D9488), Color(0xFF2563EB)],
      'avatarColorIndex': 4,
    },
  ];

  void _showSearchUsersModal(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _SearchUsersSheet(),
    );
  }

  Widget _buildFriendCardsCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, bottom: 8.0, top: 4.0),
          child: Text(
            'Practicado por amigos',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
        ),
        SizedBox(
          height: 125,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _mockPracticedCards.length,
            itemBuilder: (context, index) {
              final card = _mockPracticedCards[index];
              final friendName = card['friendName'] as String;
              final word = card['word'] as String;
              final gradient = card['gradient'] as List<Color>;
              final avatarUrl = card['friendAvatar'] as String?;
              final initials = friendName.substring(0, 1).toUpperCase();

              return Container(
                width: 90,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: gradient[0].withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        word,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        friendName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 9,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsProvider);

    // Lógica para pre-cachear imágenes de avatar antes de apagar el skeleton
    final chatsList = chatsAsync.value;
    bool hasUncachedImages = false;

    if (chatsList != null) {
      final uncachedUrls = chatsList
          .where((c) => c.avatarUrl != null && c.avatarUrl!.isNotEmpty && !_cachedAvatarUrls.contains(c.avatarUrl))
          .map((c) => c.avatarUrl!)
          .toList();

      hasUncachedImages = uncachedUrls.isNotEmpty;

      if (hasUncachedImages) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          for (final url in uncachedUrls) {
            try {
              await precacheImage(NetworkImage(url), context);
            } catch (_) {
              // Evitar que la pantalla se quede atorada si falla el internet o da error 404
            }
            if (mounted) {
              setState(() {
                _cachedAvatarUrls.add(url);
              });
            }
          }
        });
      }
    }

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
              title: const Text(AppStrings.mensajes),
              actions: [
                if (_activeSegment == 1)
                  IconButton(
                    icon: const Icon(Icons.add_box_outlined, color: AppColors.primary),
                    tooltip: 'Crear Grupo',
                    onPressed: () => _showCreateGroupModal(context),
                  ),
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => _showSearchUsersModal(context),
                ),
                const SizedBox(width: 4),
              ],
            ),
            floatingActionButton: _activeSegment == 1
                ? FloatingActionButton.extended(
                    onPressed: () => _showCreateGroupModal(context),
                    backgroundColor: AppColors.primary,
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text('Crear Grupo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  )
                : null,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Selector Segmentado de Pestañas
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildSegment(0, 'Mensajes'),
                      const SizedBox(width: 12),
                      _buildSegment(1, 'Grupos'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Carrusel de tarjetas practicadas por amigos (solo en pestaña Mensajes)
                if (_activeSegment == 0) ...[
                  _buildFriendCardsCarousel(),
                  const SizedBox(height: 16),
                ],
                
                // Listado de Chats o Grupos
                Expanded(
                  child: _activeSegment == 0
                      ? chatsAsync.when(
                          data: (chats) {
                            if (hasUncachedImages) {
                              return ListView.builder(
                                itemCount: 6,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemBuilder: (context, index) => const _ChatListTileSkeleton(),
                              );
                            }

                            if (chats.isEmpty) {
                              return const _EmptyChats();
                            }
                            return ListView.builder(
                              itemCount: chats.length,
                              padding: const EdgeInsets.only(bottom: 20),
                              itemBuilder: (context, index) {
                                final chat = chats[index];
                                return _ChatListTile(
                                  chat: chat,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatDetailScreen(chat: chat),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => ListView.builder(
                            itemCount: 6,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) => const _ChatListTileSkeleton(),
                          ),
                          error: (error, stack) => Center(
                            child: Text(
                              'Error al cargar chats: $error',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        )
                      : ref.watch(userGroupsProvider).when(
                          data: (groups) {
                            if (groups.isEmpty) {
                              return const _EmptyGroups();
                            }
                            return ListView.builder(
                              itemCount: groups.length,
                              padding: const EdgeInsets.only(bottom: 20),
                              itemBuilder: (context, index) {
                                final group = groups[index];
                                return _GroupListTile(
                                  group: group,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GroupDetailScreen(group: group),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => ListView.builder(
                            itemCount: 6,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) => const _ChatListTileSkeleton(),
                          ),
                          error: (error, stack) => Center(
                            child: Text(
                              'Error al cargar grupos: $error',
                              style: const TextStyle(color: AppColors.error),
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
  }

  Widget _buildSegment(int index, String title) {
    final isActive = _activeSegment == index;

    return GestureDetector(
      onTap: () => setState(() => _activeSegment = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.onSurfaceMuted,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}

List<String> _getLanguagesForChat(ChatEntity chat) {
  if (chat.name.toLowerCase().contains('sebas')) {
    return ['us.svg', 'fr.svg'];
  } else if (chat.name.toLowerCase().contains('pepito')) {
    return ['mx.svg', 'de.svg', 'br.svg'];
  } else {
    final flags = ['us.svg', 'mx.svg', 'fr.svg', 'de.svg', 'it.svg', 'br.svg'];
    final index1 = chat.id.hashCode.abs() % flags.length;
    final index2 = (chat.id.hashCode.abs() + 2) % flags.length;
    if (index1 == index2) {
      return [flags[index1]];
    }
    return [flags[index1], flags[index2]];
  }
}

class _ChatListTile extends ConsumerWidget {
  final ChatEntity chat;
  final VoidCallback onTap;

  const _ChatListTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarColor =
        AppColors.avatarColors[chat.avatarColorIndex % AppColors.avatarColors.length];
    final hasUnread = chat.unreadCount > 0;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.primary.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          backgroundColor: avatarColor.withValues(alpha: 0.12),
                          backgroundImage: chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty
                              ? NetworkImage(chat.avatarUrl!)
                              : null,
                          child: chat.avatarUrl == null || chat.avatarUrl!.isEmpty
                              ? Text(
                                  chat.initials,
                                  style: TextStyle(
                                    color: avatarColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (chat.isOnline)
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.online,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat.name,
                                style: TextStyle(
                                  color: AppColors.onSurface,
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 15,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                            // Banderas en la esquina superior derecha del chat
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: _getLanguagesForChat(chat).map((flag) {
                                return Container(
                                  width: 18,
                                  height: 18,
                                  margin: const EdgeInsets.only(left: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: SvgPicture.asset(
                                      'assets/flags/$flag',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatLastMessage(chat, ref.watch(authProvider).user?.id ?? ''),
                                style: TextStyle(
                                  color: hasUnread
                                      ? AppColors.onSurface
                                      : AppColors.onSurfaceMuted,
                                  fontSize: 13,
                                  fontWeight: hasUnread
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                  fontFamily: 'Inter',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatRelativeTime(chat.lastMessageTime),
                              style: TextStyle(
                                color: hasUnread
                                    ? AppColors.primary
                                    : AppColors.onSurfaceMuted,
                                fontSize: 11,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontFamily: 'Inter',
                              ),
                            ),
                            if (hasUnread) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${chat.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(height: 1, thickness: 0.5, color: AppColors.border),
        ),
      ],
    );
  }

  String _formatLastMessage(ChatEntity chat, String currentUserId) {
    if (chat.lastMessage.startsWith('[CARD]:')) {
      final isMe = chat.lastMessageSenderId == currentUserId;
      return isMe 
          ? 'Has compartido una tarjeta' 
          : '${chat.name} ha compartido una tarjeta';
    }
    return chat.lastMessage;
  }
}

class _ShimmerLoading extends StatefulWidget {
  final Widget child;
  const _ShimmerLoading({required this.child});

  @override
  State<_ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<_ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final double width = bounds.width;
    final double translation = -width + (width * 2 * slidePercent);
    return Matrix4.translationValues(translation, 0.0, 0.0);
  }
}

class _ChatListTileSkeleton extends StatelessWidget {
  const _ChatListTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Avatar Circular
              _ShimmerLoading(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFCBD5E1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Detalles del Chat (Nombre y Mensaje)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Nombre del Chat
                        _ShimmerLoading(
                          child: Container(
                            width: 100,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Flags
                        _ShimmerLoading(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCBD5E1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCBD5E1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Último mensaje
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 40),
                            child: _ShimmerLoading(
                              child: Container(
                                height: 11,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Hora
                        _ShimmerLoading(
                          child: Container(
                            width: 32,
                            height: 11,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(height: 1, thickness: 0.5, color: AppColors.border),
        ),
      ],
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: AppColors.onSurfaceMuted,
          ),
          SizedBox(height: 16),
          Text(
            'No tienes conversaciones aún',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Conecta con otros aprendices de idiomas',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SearchUsersSheet extends ConsumerStatefulWidget {
  const _SearchUsersSheet();

  @override
  ConsumerState<_SearchUsersSheet> createState() => _SearchUsersSheetState();
}

class _SearchUsersSheetState extends ConsumerState<_SearchUsersSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String val) async {
    if (val.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    final currentUserId = ref.read(authProvider).user?.id ?? '';
    final results = await ref.read(chatServiceProvider).searchProfiles(currentUserId, val);
    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * 0.85;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag bar
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Buscar Usuario',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          
          // Search Input
          TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'Escribe el nombre de un usuario...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.onSurfaceMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _onSearch('');
                      },
                    )
                  : null,
            ),
            onChanged: _onSearch,
          ),
          const SizedBox(height: 20),

          // Search Results
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              _searchController.text.isEmpty
                                  ? 'Busca por nombre para iniciar una conversación'
                                  : 'No se encontraron usuarios',
                              style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final profile = _searchResults[index];
                            final name = profile['full_name'] as String? ?? 'Usuario';
                            final otherUserId = profile['id'] as String;
                            final avatarUrl = profile['avatar_url'] as String?;
                            final initials = name.trim().isNotEmpty
                                ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                                : 'LX';
                            final color = AppColors.avatarColors[otherUserId.hashCode.abs() % AppColors.avatarColors.length];

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.12),
                                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl == null || avatarUrl.isEmpty
                                    ? Text(
                                        initials,
                                        style: TextStyle(color: color, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceMuted),
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                final currentUserId = ref.read(authProvider).user?.id ?? '';
                                
                                // Buscar o crear la sala de chat en Supabase
                                final conversationId = await ref.read(chatServiceProvider).getOrCreateConversation(currentUserId, otherUserId);

                                if (!context.mounted) return;
                                Navigator.pop(context);

                                // Mapear a entidad ChatEntity temporal
                                final chat = ChatEntity(
                                  id: conversationId,
                                  name: name,
                                  initials: initials,
                                  avatarColorIndex: otherUserId.hashCode.abs(),
                                  lastMessage: '',
                                  lastMessageTime: DateTime.now(),
                                  unreadCount: 0,
                                  isOnline: false,
                                  messages: const [],
                                );

                                // Navegar al chat
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatDetailScreen(chat: chat),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.groups_2_outlined,
            size: 64,
            color: AppColors.onSurfaceMuted,
          ),
          SizedBox(height: 16),
          Text(
            'No tienes grupos de estudio',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Crea un grupo para cooperar con tus amigos',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _GroupListTile extends StatelessWidget {
  final StudyGroupModel group;
  final VoidCallback onTap;

  const _GroupListTile({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPlant = group.growthType == 'PLANT';
    final colors = isPlant
        ? const [Color(0xFF10B981), Color(0xFF059669)]
        : const [Color(0xFF815BF5), Color(0xFF5A45FF)];

    final depthColor = Color.alphaBlend(Colors.black.withOpacity(0.25), colors[1]);
    final shadowColor = colors[0].withOpacity(0.2);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0, right: 0, bottom: 0, top: 4,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black12,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0, right: 0, bottom: 2, top: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: depthColor,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0, right: 0, top: 0, bottom: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: colors,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isPlant ? Icons.local_florist_rounded : Icons.pets_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.description ?? 'Sin descripción',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors[0].withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Nivel ${group.level}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors[0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _growthType = 'PLANT';
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa el nombre del grupo.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);
    HapticFeedback.mediumImpact();

    try {
      final userId = ref.read(authProvider).user?.id ?? '';
      await ref.read(chatServiceProvider).createGroup(
            name: name,
            description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
            growthType: _growthType,
            creatorId: userId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Grupo de estudio creado con éxito! 🎉'),
            backgroundColor: AppColors.online,
          ),
        );
        Navigator.pop(context);
        ref.invalidate(userGroupsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear grupo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: 24 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Nuevo Grupo de Estudio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: const InputDecoration(
                labelText: 'Nombre del salón / grupo',
                hintText: 'Ej: Salón de Francés B1 🇫🇷',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _descController,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: const InputDecoration(
                labelText: 'Descripción (Opcional)',
                hintText: 'Ej: Grupo para cooperar y subir de nivel la planta.',
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Mascota Cooperativa',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _growthType = 'PLANT');
                      HapticFeedback.lightImpact();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _growthType == 'PLANT' ? const Color(0xFFD1FAE5) : Colors.grey.shade50,
                        border: Border.all(
                          color: _growthType == 'PLANT' ? const Color(0xFF10B981) : AppColors.border,
                          width: _growthType == 'PLANT' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.local_florist_rounded, color: Color(0xFF047857), size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Planta de Racha',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _growthType = 'TAMAGOTCHI');
                      HapticFeedback.lightImpact();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _growthType == 'TAMAGOTCHI' ? const Color(0xFFEDE9FE) : Colors.grey.shade50,
                        border: Border.all(
                          color: _growthType == 'TAMAGOTCHI' ? const Color(0xFF815BF5) : AppColors.border,
                          width: _growthType == 'TAMAGOTCHI' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.pets_rounded, color: Color(0xFF6D28D9), size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Tamagotchi Grupal',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6D28D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _isCreating ? null : _createGroup,
              child: _isCreating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('CREAR GRUPO Y ACCEDER', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
