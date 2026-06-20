import '../../domain/entities/chat_entity.dart';

class ChatModel extends ChatEntity {
  const ChatModel({
    required super.id,
    required super.name,
    required super.initials,
    required super.avatarColorIndex,
    required super.lastMessage,
    required super.lastMessageTime,
    required super.unreadCount,
    required super.isOnline,
    required super.messages,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json, {List<MessageEntity> messages = const []}) {
    return ChatModel(
      id: json['id'] as String,
      name: json['name'] as String,
      initials: json['initials'] as String,
      avatarColorIndex: json['avatar_color_index'] as int,
      lastMessage: json['last_message'] as String? ?? '',
      lastMessageTime: DateTime.parse(json['last_message_time'] as String),
      unreadCount: json['unread_count'] as int? ?? 0,
      isOnline: json['is_online'] as bool? ?? false,
      messages: messages,
    );
  }

  Map<String, dynamic> toJson(String userId) {
    return {
      'user_id': userId,
      'name': name,
      'initials': initials,
      'avatar_color_index': avatarColorIndex,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime.toIso8601String(),
      'unread_count': unreadCount,
      'is_online': isOnline,
    };
  }
}

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.text,
    required super.isMe,
    required super.time,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      text: json['text'] as String,
      isMe: json['is_me'] as bool,
      time: DateTime.parse(json['time'] as String),
    );
  }

  Map<String, dynamic> toJson(String chatId) {
    return {
      'chat_id': chatId,
      'text': text,
      'is_me': isMe,
      'time': time.toIso8601String(),
    };
  }
}
