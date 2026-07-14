import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/chat_entity.dart';
import '../../data/models/chat_model.dart';


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
      'last_message_sender_id': senderId,
    }).eq('id', conversationId);
  }

  // Actualizar la nacionalidad/idioma activo de la conversación
  Future<void> updateActiveNationality(String conversationId, String nationality) async {
    try {
      await _supabase
          .from('conversations')
          .update({'active_nationality': nationality})
          .eq('id', conversationId);
    } catch (e) {
      // Silently catch
    }
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

// StreamProvider para escuchar las conversaciones del usuario en tiempo real con recuperación y fetch HTTP instantáneo
final chatsProvider = StreamProvider.autoDispose<List<ChatEntity>>((ref) async* {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    yield [];
    return;
  }

  final supabase = ref.read(supabaseClientProvider);

  // Función local para hacer el fetch HTTP rápido de conversaciones
  Future<List<ChatEntity>> fetchChatsHttp() async {
    final data = await supabase
        .from('conversations')
        .select('''
          id,
          last_message,
          last_message_time,
          active_nationality,
          last_message_sender_id,
          conversation_participants!inner(profile_id),
          all_participants:conversation_participants(
            profile:profiles(id, full_name, avatar_url, nationality)
          )
        ''')
        .eq('conversation_participants.profile_id', user.id)
        .order('last_message_time', ascending: false);

    return (data as List<dynamic>)
        .map((json) => ChatModel.fromJson(json, user.id))
        .toList();
  }

  // 1. Emitir inmediatamente el resultado del fetch HTTP rápido
  List<ChatEntity> currentChats = [];
  try {
    currentChats = await fetchChatsHttp();
    yield currentChats;
  } catch (e) {
    // Si falla el fetch inicial, al menos emitir lista vacía temporal o re-lanzar si es crítico
    yield [];
  }

  // 2. Escuchar en tiempo real de forma segura y tolerante a fallos
  final realtimeStream = supabase
      .from('conversations')
      .stream(primaryKey: ['id'])
      .asyncMap((_) => fetchChatsHttp());

  await for (final updatedChats in realtimeStream.handleError((error) {
    // Silenciar errores de WebSocket y mantener los datos actuales
  })) {
    currentChats = updatedChats;
    yield currentChats;
  }
});

// StreamProvider para escuchar los mensajes de una conversación en tiempo real con recuperación y fetch HTTP instantáneo
final messagesProvider = StreamProvider.family.autoDispose<List<MessageEntity>, String>((ref, conversationId) async* {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    yield [];
    return;
  }

  final supabase = ref.read(supabaseClientProvider);

  // Función local para hacer el fetch HTTP rápido de mensajes
  Future<List<MessageEntity>> fetchMessagesHttp() async {
    final data = await supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('time', ascending: true);

    return (data as List<dynamic>)
        .map((json) => MessageModel.fromJson(json, user.id))
        .toList();
  }

  // 1. Emitir inmediatamente el resultado del fetch HTTP rápido
  List<MessageEntity> currentMessages = [];
  try {
    currentMessages = await fetchMessagesHttp();
    yield currentMessages;
  } catch (e) {
    yield [];
  }

  // 2. Escuchar la tabla de mensajes en tiempo real
  final realtimeStream = supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('time', ascending: true)
      .map((list) => list.map((json) => MessageModel.fromJson(json, user.id)).toList());

  await for (final updatedMessages in realtimeStream.handleError((error) {
    // Silenciar errores de WebSocket y mantener los mensajes actuales
  })) {
    currentMessages = updatedMessages;
    yield currentMessages;
  }
});

