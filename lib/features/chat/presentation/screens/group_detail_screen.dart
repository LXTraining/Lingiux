import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/study_group.dart';
import '../../domain/entities/chat_entity.dart';
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
    final isPlant = widget.group.growthType == 'PLANT';
    final level = widget.group.level;
    final points = widget.group.growthPoints;

    // Calcular progreso
    final ptsInLevel = points % 100;
    final progress = ptsInLevel / 100.0;
    final nextLevelPoints = 100 - ptsInLevel;

    // Mascota metadatos visuales
    IconData mascotIcon;
    String mascotName;
    String mascotStage;
    List<Color> colors;

    if (isPlant) {
      colors = const [Color(0xFF10B981), Color(0xFF059669)];
      if (level <= 1) {
        mascotIcon = Icons.spa_rounded;
        mascotName = 'Semilla de Racha';
        mascotStage = 'Bebé';
      } else if (level == 2) {
        mascotIcon = Icons.grass_rounded;
        mascotName = 'Brote de Racha';
        mascotStage = 'Infantil';
      } else if (level == 3) {
        mascotIcon = Icons.eco_rounded;
        mascotName = 'Planta Joven';
        mascotStage = 'Juvenil';
      } else {
        mascotIcon = Icons.local_florist_rounded;
        mascotName = 'Planta Floreciente';
        mascotStage = 'Adulta';
      }
    } else {
      colors = const [Color(0xFF815BF5), Color(0xFF5A45FF)];
      if (level <= 1) {
        mascotIcon = Icons.egg_rounded;
        mascotName = 'Huevo Lingiux';
        mascotStage = 'Huevo';
      } else if (level == 2) {
        mascotIcon = Icons.child_care_rounded;
        mascotName = 'Mascota Bebé';
        mascotStage = 'Bebé';
      } else if (level == 3) {
        mascotIcon = Icons.cruelty_free_rounded;
        mascotName = 'Tamagotchi Joven';
        mascotStage = 'Juvenil';
      } else {
        mascotIcon = Icons.pets_rounded;
        mascotName = 'Dragon Adulto';
        mascotStage = 'Adulto';
      }
    }

    final hasContributedAsync = ref.watch(hasContributedTodayProvider(widget.group.id));
    final profileAsync = ref.watch(profileProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Mascota Box Card
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors[0].withOpacity(0.15), colors[1].withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: colors[0].withOpacity(0.2), width: 1.5),
            ),
            child: Column(
              children: [
                // Mascot 3D Pedestal
                Container(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Base pedestal
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 100,
                          height: 20,
                          decoration: BoxDecoration(
                            color: colors[0].withOpacity(0.2),
                            borderRadius: const BorderRadius.all(Radius.elliptical(50, 10)),
                          ),
                        ),
                      ),
                      // Mascot Core Orb
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: colors),
                          boxShadow: [
                            BoxShadow(
                              color: colors[0].withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            mascotIcon,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Name & Stage
                Text(
                  mascotName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors[0].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Estado: $mascotStage',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors[0],
                    ),
                  ),
                ),
              ],
            ),
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
