class Chat {
  final String id;
  final String name;
  final String initials;
  final int avatarColorIndex;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final List<Message> messages;

  const Chat({
    required this.id,
    required this.name,
    required this.initials,
    required this.avatarColorIndex,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isOnline,
    required this.messages,
  });
}

class Message {
  final String id;
  final String text;
  final bool isMe;
  final DateTime time;

  const Message({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
  });
}
