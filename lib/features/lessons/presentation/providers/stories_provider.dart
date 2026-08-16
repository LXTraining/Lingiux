import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/story_model.dart';

final storiesServiceProvider = Provider((ref) => StoriesService(ref.read(supabaseClientProvider)));

class StoriesService {
  final SupabaseClient _supabase;
  StoriesService(this._supabase);

  // Guardar un nuevo relato
  Future<void> saveStory({
    required String creatorId,
    required String title,
    required String content,
    required String language,
    required String difficulty,
    Map<String, dynamic>? metadata,
  }) async {
    await _supabase.from('stories').insert({
      'creator_id': creatorId,
      'title': title,
      'content': content,
      'language': language,
      'difficulty': difficulty,
      'metadata': metadata ?? {},
    });
  }

  // Actualizar un relato existente
  Future<void> updateStory({
    required String storyId,
    required String title,
    required String content,
    required String language,
    required String difficulty,
    Map<String, dynamic>? metadata,
  }) async {
    await _supabase.from('stories').update({
      'title': title,
      'content': content,
      'language': language,
      'difficulty': difficulty,
      'metadata': metadata ?? {},
    }).eq('id', storyId);
  }

  // Eliminar un relato
  Future<void> deleteStory(String storyId) async {
    await _supabase.from('stories').delete().eq('id', storyId);
  }

  // Obtener todos los relatos ordenados por fecha de creación
  Future<List<StoryModel>> fetchStories() async {
    final response = await _supabase
        .from('stories')
        .select()
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => StoryModel.fromJson(json))
        .toList();
  }

  // Obtener relatos creados por un usuario específico
  Future<List<StoryModel>> fetchStoriesByCreator(String creatorId) async {
    final response = await _supabase
        .from('stories')
        .select()
        .eq('creator_id', creatorId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => StoryModel.fromJson(json))
        .toList();
  }
}

// Provider de relatos globales
final storiesListProvider = FutureProvider<List<StoryModel>>((ref) async {
  final service = ref.watch(storiesServiceProvider);
  return service.fetchStories();
});

// Provider de relatos creados por un usuario específico
final userStoriesProvider = FutureProvider.autoDispose.family<List<StoryModel>, String>((ref, userId) async {
  final service = ref.watch(storiesServiceProvider);
  return service.fetchStoriesByCreator(userId);
});
