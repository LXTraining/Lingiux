import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/study_group.dart';
import '../../data/models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../screens/chat_detail_screen.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../features/profile/presentation/providers/added_people_provider.dart';
import '../../../../features/vocabulary/domain/models/word_card_model.dart';
import '../../../../features/vocabulary/presentation/providers/vocabulary_provider.dart';
import '../../../../features/vocabulary/presentation/screens/word_detail_screen.dart';

// Provider para obtener los participantes de la conversación grupal
final groupMembersProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, conversationId) async {
  return ref.read(chatServiceProvider).getGroupMembers(conversationId);
});

// Provider para obtener participantes con sus contribuciones de racha acumuladas
final groupMembersWithContributionsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, Map<String, String>>((ref, params) async {
  final groupId = params['groupId']!;
  final conversationId = params['conversationId']!;
  return ref.read(chatServiceProvider).getGroupMembersWithContributions(groupId, conversationId);
});

// Provider para comprobar si el usuario ya contribuyó hoy
final hasContributedTodayProvider = FutureProvider.family.autoDispose<bool, String>((ref, groupId) async {
  final userId = ref.read(authProvider).user?.id ?? '';
  return ref.read(chatServiceProvider).hasContributedToday(groupId, userId);
});

class GroupDetailScreen extends ConsumerStatefulWidget {
  final StudyGroupModel group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  OverlayEntry? _overlayEntry;
  final Map<String, WordCardModel> _selectedCardsCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _dismissOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showWordCard(String messageId, String word, Offset globalPosition, Size wordSize) {
    _dismissOverlay();

    final cleanWord = word.replaceAll(RegExp(r"[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ']"), '');
    if (cleanWord.length < 2) return;

    final wordList = ref.read(wordCardsProvider).value ?? [];
    final matches = wordList.where((w) => w.word.toLowerCase() == cleanWord.toLowerCase()).toList();

    WordCardModel? selectedWordCard;
    if (matches.isNotEmpty) {
      final cacheKey = "${messageId}_${cleanWord.toLowerCase()}";
      if (_selectedCardsCache.containsKey(cacheKey)) {
        selectedWordCard = _selectedCardsCache[cacheKey];
      } else {
        selectedWordCard = matches[math.Random().nextInt(matches.length)];
        _selectedCardsCache[cacheKey] = selectedWordCard!;
      }
    }

    ref.read(audioServiceProvider).playTap();
    HapticFeedback.lightImpact();

    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 96.0;
    const cardHeight = 136.0;
    const spacing = 8.0;
    final safeAreaTop = MediaQuery.of(context).padding.top + kToolbarHeight;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final wordCenterX = globalPosition.dx;
    double left = wordCenterX - cardWidth / 2;
    double top = globalPosition.dy - cardHeight - spacing;

    bool isBelow = false;
    if (top < safeAreaTop + 8.0) {
      top = globalPosition.dy + wordSize.height;
      isBelow = true;
    }

    left = left.clamp(8.0, screenSize.width - cardWidth - 8);
    top = top.clamp(
      safeAreaTop + 8.0,
      screenSize.height - cardHeight - safeAreaBottom - 16.0,
    );

    final arrowLeft = (wordCenterX - left).clamp(16.0, cardWidth - 16.0);
    final cardController = FlippableCardController();

    _overlayEntry = OverlayEntry(
      builder: (_) => OverlayEntrance(
        left: left,
        top: top,
        isBelow: isBelow,
        onDismiss: _dismissOverlay,
        onShare: () {},
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity!.abs() > 200) {
            final swipeRight = details.primaryVelocity! > 0;
            cardController.flip(swipeRight: swipeRight);
            HapticFeedback.selectionClick();
          }
        },
        child: FlippableCard(
          controller: cardController,
          isBelow: isBelow,
          arrowLeft: arrowLeft,
          front: WordMiniCardFront(
            word: cleanWord,
            card: selectedWordCard,
            onTap: () {
              _dismissOverlay();
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      WordDetailScreen(
                        selectedWord: cleanWord,
                        cardId: selectedWordCard?.id,
                        conversationId: widget.group.conversationId,
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      ),
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 280),
                ),
              );
            },
          ),
          back: WordMiniCardBack(
            word: cleanWord,
            card: selectedWordCard,
            onTap: () {
              _dismissOverlay();
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      WordDetailScreen(
                        selectedWord: cleanWord,
                        cardId: selectedWordCard?.id,
                        conversationId: widget.group.conversationId,
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      ),
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 280),
                ),
              );
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userId = ref.read(authProvider).user?.id ?? '';
    _messageController.clear();

    try {
      await ref.read(chatServiceProvider).sendMessage(widget.group.conversationId, userId, text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar mensaje: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _contributeStreak(int streakCount) async {
    final userId = ref.read(authProvider).user?.id ?? '';
    HapticFeedback.vibrate();

    try {
      await ref.read(chatServiceProvider).contributeStreak(widget.group.id, userId, streakCount);
      
      // Invalidar providers para actualizar la UI en tiempo real
      ref.invalidate(userGroupsProvider);
      ref.invalidate(hasContributedTodayProvider(widget.group.id));
      ref.invalidate(groupMembersWithContributionsProvider({
        'groupId': widget.group.id,
        'conversationId': widget.group.conversationId,
      }));

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('¡Aporte Exitoso! 🔥', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Colors.orange, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Has aportado tus $streakCount días de racha a la mascota del grupo.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('¡Súper!', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aportar: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showInviteStudentsModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _InviteStudentsSheet(
        groupId: widget.group.id,
        conversationId: widget.group.conversationId,
        onInvited: () {
          ref.invalidate(groupMembersProvider(widget.group.conversationId));
          ref.invalidate(groupMembersWithContributionsProvider({
            'groupId': widget.group.id,
            'conversationId': widget.group.conversationId,
          }));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Chat', icon: Icon(Icons.chat_bubble_outline_rounded)),
            Tab(text: 'Evolución', icon: Icon(Icons.local_florist_rounded)),
            Tab(text: 'Miembros', icon: Icon(Icons.groups_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(),
          _buildEvolutionTab(),
          _buildMembersTab(),
        ],
      ),
    );
  }

  // PESTAÑA 1: CHAT GRUPAL
  Widget _buildChatTab() {
    final messagesAsync = ref.watch(messagesProvider(widget.group.conversationId));
    final membersAsync = ref.watch(groupMembersProvider(widget.group.conversationId));
    final currentUserId = ref.watch(authProvider).user?.id ?? '';

    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    'No hay mensajes aún. ¡Comiencen a hablar!',
                    style: TextStyle(color: AppColors.onSurfaceMuted),
                  ),
                );
              }

              // Mapear participantes para obtener avatar y nombre
              final members = membersAsync.value ?? [];
              final membersMap = {
                for (final m in members) m['id'] as String: m
              };

              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index] as MessageModel;
                  final isMe = msg.senderId == currentUserId;
                  final senderProfile = membersMap[msg.senderId];
                  final senderName = senderProfile?['full_name'] as String? ?? 'Usuario';
                  final senderAvatar = senderProfile?['avatar_url'] as String?;

                  return MessageBubble(
                    message: msg,
                    conversationId: widget.group.conversationId,
                    onWordTap: _showWordCard,
                    senderName: isMe ? null : senderName,
                    senderAvatar: isMe ? null : senderAvatar,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: const InputDecoration(
                    hintText: 'Enviar mensaje...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // PESTAÑA 2: EVOLUCIÓN (PLANTA / TAMAGOTCHI)
  Widget _buildEvolutionTab() {
    final level = widget.group.level;
    final points = widget.group.growthPoints;

    // Calcular progreso
    final ptsInLevel = points % 100;
    final progress = ptsInLevel / 100.0;
    final nextLevelPoints = 100 - ptsInLevel;

    // Mascota metadatos visuales
    String mascotStage;
    const colors = [Color(0xFF10B981), Color(0xFF059669)];

    if (level <= 1) {
      mascotStage = 'Bebé';
    } else if (level == 2) {
      mascotStage = 'Infantil';
    } else if (level == 3) {
      mascotStage = 'Juvenil';
    } else {
      mascotStage = 'Adulta';
    }

    final hasContributedAsync = ref.watch(hasContributedTodayProvider(widget.group.id));
    final profileAsync = ref.watch(profileProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Mascota Box Card (Planta Interactiva y Animada de Racha)
          GroupMascotPlantWidget(
            level: level,
            stageName: mascotStage,
            colors: colors,
          ),
          const SizedBox(height: 28),

          // Progress Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nivel $level',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                    Text(
                      '$ptsInLevel / 100 pts',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(colors[0]),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Faltan $nextLevelPoints puntos para alcanzar el nivel ${level + 1}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Aportar Racha Button
          hasContributedAsync.when(
            data: (hasContributed) {
              final profile = profileAsync.value;
              final streakCount = profile?['streak_count'] as int? ?? 1;

              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasContributed ? Colors.grey.shade200 : Colors.orange.shade700,
                    foregroundColor: hasContributed ? Colors.grey : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: hasContributed ? 0 : 2,
                  ),
                  icon: const Icon(Icons.local_fire_department_rounded, size: 24),
                  label: Text(
                    hasContributed ? 'YA APORTASTE HOY 🔥' : 'APORTAR RACHA (+$streakCount pts) 🔥',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: hasContributed ? null : () => _contributeStreak(streakCount),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ],
      ),
    );
  }

  // PESTAÑA 3: MIEMBROS Y PARTICIPANTES
  Widget _buildMembersTab() {
    final membersAsync = ref.watch(groupMembersWithContributionsProvider({
      'groupId': widget.group.id,
      'conversationId': widget.group.conversationId,
    }));

    return Column(
      children: [
        Expanded(
          child: membersAsync.when(
            data: (members) {
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final name = member['full_name'] as String? ?? 'Usuario';
                  final avatarUrl = member['avatar_url'] as String?;
                  final pts = member['total_contributed'] as int? ?? 0;
                  final isCreator = member['id'] == widget.group.creatorId;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.border,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? Text(name.substring(0, 1).toUpperCase()) : null,
                      ),
                      title: Row(
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (isCreator) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Creador', style: TextStyle(fontSize: 8, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 18),
                          const SizedBox(width: 4),
                          Text('$pts pts aportados', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('INVITAR INTEGRANTE', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _showInviteStudentsModal,
            ),
          ),
        ),
      ],
    );
  }
}

// Bottom sheet para invitar estudiantes
class _InviteStudentsSheet extends ConsumerStatefulWidget {
  final String groupId;
  final String conversationId;
  final VoidCallback onInvited;

  const _InviteStudentsSheet({
    required this.groupId,
    required this.conversationId,
    required this.onInvited,
  });

  @override
  ConsumerState<_InviteStudentsSheet> createState() => _InviteStudentsSheetState();
}

class _InviteStudentsSheetState extends ConsumerState<_InviteStudentsSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    final results = await ref.read(chatServiceProvider).searchProfiles(
          ref.read(authProvider).user?.id ?? '',
          query,
        );
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _inviteUser(String profileId, String name) async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(chatServiceProvider).inviteMember(widget.conversationId, profileId);
      widget.onInvited();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡$name ha sido invitado al grupo! 🎉'),
            backgroundColor: AppColors.online,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al invitar: El usuario ya es parte del grupo.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(addedPeopleProfilesProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
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
            'Invitar Integrante',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 16),

          // Buscador
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onChanged: _searchUsers,
          ),
          const SizedBox(height: 16),

          // Contenedor de lista flexible
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: _searchController.text.trim().isNotEmpty
                ? _isSearching
                    ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                    : _searchResults.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No se encontraron usuarios.', style: TextStyle(color: AppColors.onSurfaceMuted))))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              final name = user['full_name'] as String? ?? 'Usuario';
                              final avatarUrl = user['avatar_url'] as String?;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.border,
                                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                  child: avatarUrl == null ? Text(name.substring(0, 1).toUpperCase()) : null,
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                trailing: TextButton(
                                  onPressed: () => _inviteUser(user['id'] as String, name),
                                  child: const Text('Invitar'),
                                ),
                              );
                            },
                          )
                : friendsAsync.when(
                    data: (friends) {
                      if (friends.isEmpty) {
                        return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No tienes amigos agregados aún.', style: TextStyle(color: AppColors.onSurfaceMuted))));
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          final name = friend['full_name'] as String? ?? 'Usuario';
                          final avatarUrl = friend['avatar_url'] as String?;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.border,
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null ? Text(name.substring(0, 1).toUpperCase()) : null,
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: TextButton(
                              onPressed: () => _inviteUser(friend['id'] as String, name),
                              child: const Text('Invitar'),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  ),
          ),
        ],
      ),
    );
  }
}

class GroupMascotPlantWidget extends StatefulWidget {
  final int level;
  final String stageName;
  final List<Color> colors;

  const GroupMascotPlantWidget({
    super.key,
    required this.level,
    required this.stageName,
    required this.colors,
  });

  @override
  State<GroupMascotPlantWidget> createState() => _GroupMascotPlantWidgetState();
}

class _GroupMascotPlantWidgetState extends State<GroupMascotPlantWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  String _currentSpeech = '¡Hola! Ayúdame a crecer fuerte aportando tus días de racha. 🌱';
  bool _isPressed = false;

  final List<String> _speeches = [
    '¡Hola! Con tu racha diaria me ayudas a crecer fuerte. 🌱',
    '¡Glup! El agua de tus rachas sabe deliciosa. 💧',
    '¡Mmm... siento el sol del aprendizaje brillando sobre mí! ☀️',
    '¡Sigan practicando en equipo para verme florecer! 🌸',
    '¡Zzz... mis hojas están descansando del inglés! 🍃',
    '¡Hojas listas, mentes listas! ¡A practicar hoy! 📚',
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
    return Container(
      width: double.infinity,
      height: 310,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.colors[0].withOpacity(0.15), widget.colors[1].withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: widget.colors[0].withOpacity(0.2), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Partículas/círculos decorativos de fondo con brillos suaves
          Positioned(
            top: 60,
            left: 50,
            child: _buildGlowingBubble(16, widget.colors[0].withOpacity(0.15)),
          ),
          Positioned(
            bottom: 80,
            right: 60,
            child: _buildGlowingBubble(24, widget.colors[1].withOpacity(0.1)),
          ),
          Positioned(
            top: 100,
            right: 45,
            child: _buildGlowingBubble(12, Colors.white.withOpacity(0.25)),
          ),

          // 2. Globo de Diálogo Flotante (Speech Balloon)
          Positioned(
            top: 20,
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 250),
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
                        fontSize: 11.5,
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

          // 3. Pedestal / Plataforma
          Positioned(
            bottom: 95,
            child: Container(
              width: 140,
              height: 16,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.elliptical(140, 16)),
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
                    color: widget.colors[0].withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),

          // 4. Planta Flotante (Cuerpo y animación)
          Positioned(
            bottom: 102,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatAnimation.value),
                  child: GestureDetector(
                    onTap: _onTapMascot,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Aura trasera resplandeciente
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.colors[0].withOpacity(0.25),
                                blurRadius: 25,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),

                        // Anillo orbital rotando
                        Transform.rotate(
                          angle: _rotateAnimation.value,
                          child: CustomPaint(
                            size: const Size(110, 110),
                            painter: PlantOrbitalRingPainter(color: widget.colors[0]),
                          ),
                        ),

                        // Planta del grupo
                        AnimatedScale(
                          scale: _isPressed ? 0.85 : _scaleAnimation.value,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutBack,
                          child: _buildPlantVisual(widget.level, widget.colors),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 5. Nombre y estadísticas de nivel abajo de la tarjeta
          Positioned(
            bottom: 20,
            child: Column(
              children: [
                Text(
                  widget.level <= 1
                      ? 'Semilla de Racha'
                      : widget.level == 2
                          ? 'Brote de Racha'
                          : widget.level == 3
                              ? 'Planta Joven'
                              : 'Planta Floreciente',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.colors[0].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Estado: ${widget.stageName}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: widget.colors[0],
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

  Widget _buildPlantVisual(int level, List<Color> colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPlantBody(level, colors),
        const SizedBox(height: 2),
        _buildPot(),
      ],
    );
  }

  Widget _buildPot() {
    return Container(
      width: 48,
      height: 26,
      decoration: const BoxDecoration(
        color: Color(0xFFD97706), // Terracotta clay pot
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
          topLeft: Radius.circular(2),
          topRight: Radius.circular(2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 52,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFB45309),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Positioned(
            bottom: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('◡', style: TextStyle(color: Colors.white, fontSize: 8, height: 1.0, fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                Text('◡', style: TextStyle(color: Colors.white, fontSize: 8, height: 1.0, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantBody(int level, List<Color> colors) {
    if (level <= 1) {
      return Container(
        width: 30,
        height: 30,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Icon(Icons.spa_rounded, color: colors[0], size: 24),
            const Positioned(
              top: 6,
              child: Row(
                children: [
                  Text('z', style: TextStyle(fontSize: 6, color: Colors.white70)),
                  Text('Z', style: TextStyle(fontSize: 8, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (level == 2) {
      return Container(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Icon(Icons.grass_rounded, color: colors[0], size: 36),
            const Positioned(
              bottom: 8,
              child: Row(
                children: [
                  Text('•', style: TextStyle(color: Colors.white, fontSize: 8)),
                  SizedBox(width: 4),
                  Text('•', style: TextStyle(color: Colors.white, fontSize: 8)),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (level == 3) {
      return Container(
        width: 50,
        height: 55,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Icon(Icons.eco_rounded, color: colors[0], size: 48),
            const Positioned(
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('•', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text('‿', style: TextStyle(color: Colors.white, fontSize: 8, height: 0.8)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: 60,
        height: 65,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: 0,
              child: Icon(Icons.eco_rounded, color: colors[0], size: 50),
            ),
            Positioned(
              top: 0,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.local_florist_rounded, color: Colors.pinkAccent, size: 28),
              ),
            ),
            const Positioned(
              bottom: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('^', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text('^', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text('o', style: TextStyle(color: Colors.white, fontSize: 7, height: 0.8)),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}

class PlantOrbitalRingPainter extends CustomPainter {
  final Color color;
  const PlantOrbitalRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height * 0.35,
    );

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()..addOval(rect);
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.25);
    canvas.translate(-center.dx, -center.dy);
    
    const double dashWidth = 5;
    const double dashSpace = 5;
    
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
