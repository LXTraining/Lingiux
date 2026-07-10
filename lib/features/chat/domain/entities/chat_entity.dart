class ChatEntity {
  final String id;
  final String name;
  final String initials;
  final int avatarColorIndex;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final List<MessageEntity> messages;
  final String? avatarUrl;
  final String? otherUserId;
  final String? nationality;

  const ChatEntity({
    required this.id,
    required this.name,
    required this.initials,
    required this.avatarColorIndex,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isOnline,
    required this.messages,
    this.avatarUrl,
    this.otherUserId,
    this.nationality,
  });
}

class MessageEntity {
  final String id;
  final String text;
  final bool isMe;
  final DateTime time;

  const MessageEntity({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
  });
}
