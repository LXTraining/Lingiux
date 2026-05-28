import 'package:flutter/material.dart';
import '../../domain/entities/chat_entity.dart';
import 'chat_detail_screen.dart';
import '../../../../../shared/data/mock_data.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/utils/formatters.dart';

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.mensajes),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: mockChats.isEmpty
          ? const _EmptyChats()
          : ListView.separated(
              itemCount: mockChats.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: 80,
              ),
              itemBuilder: (context, index) {
                final chat = mockChats[index];
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
            ),
    );
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

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primary.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: avatarColor.withAlpha(38),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: avatarColor.withAlpha(77),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      chat.initials,
                      style: TextStyle(
                        color: avatarColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                if (chat.isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.background,
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
                          ),
                        ),
                      ),
                      Text(
                        formatRelativeTime(chat.lastMessageTime),
                        style: TextStyle(
                          color: hasUnread
                              ? AppColors.primary
                              : AppColors.onSurfaceMuted,
                          fontSize: 12,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
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
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${chat.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
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
