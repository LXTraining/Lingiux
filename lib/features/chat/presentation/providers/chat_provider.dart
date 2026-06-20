import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/chat_entity.dart';
import '../../data/models/chat_model.dart';

// Proveedor del servicio de chat para enviar mensajes
final chatServiceProvider = Provider((ref) => ChatService(ref.read(supabaseClientProvider)));

class ChatService {
  final SupabaseClient _supabase;
  ChatService(this._supabase);

  Future<void> sendMessage(String chatId, String text) async {
    if (text.trim().isEmpty) return;

    final now = DateTime.now();

    // 1. Insertar el mensaje en la base de datos
    await _supabase.from('messages').insert({
      'chat_id': chatId,
      'text': text.trim(),
      'is_me': true,
      'time': now.toIso8601String(),
    });

    // 2. Actualizar la metadata del chat (último mensaje, hora y limpiar no leídos)
    await _supabase.from('chats').update({
      'last_message': text.trim(),
      'last_message_time': now.toIso8601String(),
      'unread_count': 0,
    }).eq('id', chatId);
  }
}

// StreamProvider para escuchar la lista de chats del usuario en tiempo real
final chatsProvider = StreamProvider.autoDispose<List<ChatEntity>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return const Stream.empty();

  final supabase = ref.read(supabaseClientProvider);

  // Sembrar 1 contacto inicial (Emma Watson) si no existen chats
  _seedIfEmpty(user.id, supabase);

  return supabase
      .from('chats')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .order('last_message_time', ascending: false)
      .map((list) => list.map((json) => ChatModel.fromJson(json)).toList());
});

// StreamProvider para escuchar los mensajes de un chat específico en tiempo real
final messagesProvider = StreamProvider.family.autoDispose<List<MessageEntity>, String>((ref, chatId) {
  final supabase = ref.read(supabaseClientProvider);

  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('chat_id', chatId)
      .order('time', ascending: true)
      .map((list) => list.map((json) => MessageModel.fromJson(json)).toList());
});

// Función interna para sembrar el contacto inicial de Emma Watson si la tabla está vacía
Future<void> _seedIfEmpty(String userId, SupabaseClient supabase) async {
  try {
    final countResponse = await supabase
        .from('chats')
        .select('id')
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();

    if (countResponse == null) {
      // 1. Insertar el chat de Emma Watson
      final chatInsert = await supabase.from('chats').insert({
        'user_id': userId,
        'name': 'Emma Watson',
        'initials': 'EW',
        'avatar_color_index': 0,
        'last_message': 'I think we need to transcend our current understanding to grasp the full paradigm shift happening around us.',
        'last_message_time': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'unread_count': 0,
        'is_online': true,
      }).select().single();

      final chatId = chatInsert['id'] as String;

      // 2. Insertar los mensajes iniciales para simular la conversación
      await supabase.from('messages').insert([
        {
          'chat_id': chatId,
          'text': 'Hey! Have you read that article about the ephemeral nature of digital memories?',
          'is_me': false,
          'time': DateTime.now().subtract(const Duration(hours: 1, minutes: 20)).toIso8601String(),
        },
        {
          'chat_id': chatId,
          'text': 'Yes! It was quite fascinating. The author had such an eloquent way of describing how technology shapes our perception.',
          'is_me': true,
          'time': DateTime.now().subtract(const Duration(hours: 1, minutes: 15)).toIso8601String(),
        },
        {
          'chat_id': chatId,
          'text': 'Exactly! I found the part about serendipity in human connections through social media particularly interesting.',
          'is_me': false,
          'time': DateTime.now().subtract(const Duration(hours: 1, minutes: 10)).toIso8601String(),
        },
        {
          'chat_id': chatId,
          'text': 'The whole concept is quite ambiguous though. Does technology truly enhance our resilience as social beings?',
          'is_me': true,
          'time': DateTime.now().subtract(const Duration(hours: 1, minutes: 5)).toIso8601String(),
        },
        {
          'chat_id': chatId,
          'text': 'I think we need to transcend our current understanding to grasp the full paradigm shift happening around us.',
          'is_me': false,
          'time': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        },
      ]);
    }
  } catch (e) {
    // Falla silenciosa para desarrollo seguro
  }
}
