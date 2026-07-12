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
    super.avatarUrl,
    super.otherUserId,
    super.nationality,
    super.activeNationality,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json, String currentUserId) {
    final participants = json['all_participants'] as List<dynamic>? ?? [];
    
    // Buscar el participante que NO es el usuario actual
    final otherParticipant = participants.firstWhere(
      (p) => p['profile'] != null && p['profile']['id'] != currentUserId,
      orElse: () => null,
    );

    final otherProfile = otherParticipant != null ? otherParticipant['profile'] as Map<String, dynamic> : null;
    final otherName = otherProfile?['full_name'] as String? ?? 'Usuario de Lingiux';
    final avatarUrl = otherProfile?['avatar_url'] as String?;
    final otherUserId = otherProfile?['id'] as String?;
    final nationality = otherProfile?['nationality'] as String?;
    final activeNationality = json['active_nationality'] as String? ?? 'us';
    
    final initials = otherName.trim().isNotEmpty
        ? otherName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'LX';

    // Generar un color avatar estable basado en el hash del nombre
    final avatarColorIndex = otherName.hashCode.abs();

    return ChatModel(
      id: json['id'] as String,
      name: otherName,
      initials: initials,
      avatarColorIndex: avatarColorIndex,
      lastMessage: json['last_message'] as String? ?? '',
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'] as String)
          : DateTime.now(),
      unreadCount: 0,
      isOnline: false,
      messages: const [],
      avatarUrl: avatarUrl,
      otherUserId: otherUserId,
      nationality: nationality,
      activeNationality: activeNationality,
    );
  }
}

class MessageModel extends MessageEntity {
  final String senderId;

  const MessageModel({
    required super.id,
    required super.text,
    required super.isMe,
    required super.time,
    required this.senderId,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json, String currentUserId) {
    final senderId = json['sender_id'] as String;
    return MessageModel(
      id: json['id'] as String,
      text: json['text'] as String,
      isMe: senderId == currentUserId,
      time: DateTime.parse(json['time'] as String),
      senderId: senderId,
    );
  }

  Map<String, dynamic> toJson(String conversationId) {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'text': text,
      'time': time.toIso8601String(),
    };
  }
}
