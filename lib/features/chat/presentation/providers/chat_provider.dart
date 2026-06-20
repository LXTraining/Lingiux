import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/chat_entity.dart';
import '../../data/models/chat_model.dart';

// Constante ID de Emma Watson para la siembra
const emmaWatsonId = 'e11a9a10-0000-0000-0000-000000000000';

// Proveedor del servicio de chat
final chatServiceProvider = Provider((ref) => ChatService(ref.read(supabaseClientProvider)));

class ChatService {
  final SupabaseClient _supabase;
  ChatService(this._supabase);

  // Enviar mensaje en una conversación compartida
  Future<void> sendMessage(String conversationId, String senderId, String text) async {
    if (text.trim().isEmpty) return;

    final now = DateTime.now();

    // 1. Insertar el mensaje
    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'text': text.trim(),
      'time': now.toIso8601String(),
    });

    // 2. Actualizar metadatos en la conversación compartida
    await _supabase.from('conversations').update({
      'last_message': text.trim(),
      'last_message_time': now.toIso8601String(),
    }).eq('id', conversationId);
  }

  // Buscar perfiles de otros usuarios para chatear
  Future<List<Map<String, dynamic>>> searchProfiles(String currentUserId, String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .neq('id', currentUserId)
          .ilike('full_name', '%${query.trim()}%')
          .limit(10);
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    }
  }

  // Buscar o crear conversación entre dos usuarios
  Future<String> getOrCreateConversation(String currentUserId, String otherUserId) async {
    // 1. Buscar si ya existe una conversación común
    final myParticipants = await _supabase
        .from('conversation_participants')
        .select('conversation_id')
        .eq('profile_id', currentUserId);

    final myConvIds = (myParticipants as List<dynamic>)
        .map((p) => p['conversation_id'] as String)
        .toList();

    if (myConvIds.isNotEmpty) {
      final commonParticipant = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .inFilter('conversation_id', myConvIds)
          .eq('profile_id', otherUserId)
          .limit(1)
          .maybeSingle();

      if (commonParticipant != null) {
        return commonParticipant['conversation_id'] as String;
      }
    }

    // 2. Si no existe, crear una nueva conversación
    final convInsert = await _supabase.from('conversations').insert({
      'last_message': 'Conversación iniciada',
      'last_message_time': DateTime.now().toIso8601String(),
    }).select().single();

    final convId = convInsert['id'] as String;

    // 3. Insertar ambos participantes
    await _supabase.from('conversation_participants').insert([
      {'conversation_id': convId, 'profile_id': currentUserId},
      {'conversation_id': convId, 'profile_id': otherUserId},
    ]);

    return convId;
  }
}

// StreamProvider para escuchar las conversaciones del usuario en tiempo real
final chatsProvider = StreamProvider.autoDispose<List<ChatEntity>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return const Stream.empty();

  final supabase = ref.read(supabaseClientProvider);

  // Sembrar 1 contacto inicial (Emma Watson) si no tiene conversaciones
  _seedIfEmpty(user.id, supabase);

  // Escuchar la tabla conversaciones. Cada cambio (incluyendo actualizaciones de last_message)
  // gatillará el recargado de los datos relacionales de la conversación.
  return supabase
      .from('conversations')
      .stream(primaryKey: ['id'])
      .asyncMap((_) async {
        final data = await supabase
            .from('conversations')
            .select('''
              id,
              last_message,
              last_message_time,
              conversation_participants!inner(profile_id),
              all_participants:conversation_participants(
                profile:profiles(id, full_name, avatar_url)
              )
            ''')
            .eq('conversation_participants.profile_id', user.id)
            .order('last_message_time', ascending: false);

        return (data as List<dynamic>)
            .map((json) => ChatModel.fromJson(json, user.id))
            .toList();
      });
});

// StreamProvider para escuchar los mensajes de una conversación en tiempo real
final messagesProvider = StreamProvider.family.autoDispose<List<MessageEntity>, String>((ref, conversationId) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return const Stream.empty();

  final supabase = ref.read(supabaseClientProvider);

  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('time', ascending: true)
      .map((list) => list.map((json) => MessageModel.fromJson(json, user.id)).toList());
});

// Sembrar el contacto de Emma Watson
Future<void> _seedIfEmpty(String userId, SupabaseClient supabase) async {
  try {
    final existing = await supabase
        .from('conversation_participants')
        .select('conversation_id')
        .eq('profile_id', userId)
        .limit(1)
        .maybeSingle();

    if (existing == null) {
      // 1. Crear conversación
      final conv = await supabase.from('conversations').insert({
        'last_message': 'I think we need to transcend our current understanding to grasp the full paradigm shift happening around us.',
        'last_message_time': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      }).select().single();

      final convId = conv['id'] as String;

      // 2. Insertar participantes
      await supabase.from('conversation_participants').insert([
        {'conversation_id': convId, 'profile_id': userId},
        {'conversation_id': convId, 'profile_id': emmaWatsonId},
      ]);

      // 3. Insertar mensajes iniciales
      await supabase.from('messages').insert([
        {
          'conversation_id': convId,
          'sender_id': emmaWatsonId,
          'text': 'Hey! Have you read that article about the ephemeral nature of digital memories?',
          'time': DateTime.now().subtract(const Duration(hours: 1, minutes: 20)).toIso8601String(),
        },
        {
          'conversation_id': convId,
          'sender_id': userId,
          'text': 'Yes! It was quite fascinating. The author had such an eloquent way of describing how technology shapes our perception.',
          'time': DateTime.now().subtract(const Duration(hours: 1, minutes: 15)).toIso8601String(),
        },
        {
          'conversation_id': convId,
          'sender_id': emmaWatsonId,
          'text': 'Exactly! I found the part about serendipity in human connections through social media particularly interesting.',
          'time': DateTime.now().subtract(const Duration(hours: 1, minutes: 10)).toIso8601String(),
        },
        {
          'conversation_id': convId,
          'sender_id': userId,
          'text': 'The whole concept is quite ambiguous though. Does technology truly enhance our resilience as social beings?',
          'time': DateTime.now().subtract(const Duration(hours: 1, minutes: 5)).toIso8601String(),
        },
        {
          'conversation_id': convId,
          'sender_id': emmaWatsonId,
          'text': 'I think we need to transcend our current understanding to grasp the full paradigm shift happening around us.',
          'time': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        },
      ]);
    }
  } catch (e) {
    // Silencioso
  }
}
