import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/entities/chat_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_detail_screen.dart';
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
            appBar: AppBar(
              title: const Text(AppStrings.mensajes),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showSearchUsersModal(context),
                ),
                const SizedBox(width: 4),
              ],
            ),
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
                
                // Listado de Chats
                Expanded(
                  child: chatsAsync.when(
                    data: (chats) {
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
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                    error: (error, stack) => Center(
                      child: Text(
                        'Error al cargar chats: $error',
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

class _ChatListTile extends StatelessWidget {
  final ChatEntity chat;
  final VoidCallback onTap;

  const _ChatListTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                                chat.lastMessage,
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

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomInset + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
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
                        shrinkWrap: true,
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
        ],
      ),
    );
  }
}
