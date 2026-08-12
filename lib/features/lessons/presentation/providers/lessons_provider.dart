import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/lesson_model.dart';

final lessonServiceProvider = Provider((ref) => LessonService(ref.read(supabaseClientProvider)));

class LessonService {
  final SupabaseClient _supabase;
  LessonService(this._supabase);

  // Crear una nueva lección en Supabase
  Future<void> saveLesson({
    required String creatorId,
    required String title,
    String? description,
    required String language,
    required String difficulty,
    required List<String> cardIds,
    required List<dynamic> exercisesJson,
  }) async {
    await _supabase.from('lessons').insert({
      'creator_id': creatorId,
      'title': title,
      'description': description,
      'language': language,
      'difficulty': difficulty,
      'card_ids': cardIds,
      'exercises': exercisesJson,
    });
  }

  // Actualizar una lección existente en Supabase
  Future<void> updateLesson({
    required String lessonId,
    required String title,
    String? description,
    required String language,
    required String difficulty,
    required List<String> cardIds,
    required List<dynamic> exercisesJson,
  }) async {
    await _supabase.from('lessons').update({
      'title': title,
      'description': description,
      'language': language,
      'difficulty': difficulty,
      'card_ids': cardIds,
      'exercises': exercisesJson,
    }).eq('id', lessonId);
  }

  // Eliminar una lección
  Future<void> deleteLesson(String lessonId) async {
    await _supabase.from('lessons').delete().eq('id', lessonId);
  }

  // Obtener todas las lecciones ordenadas por fecha
  Future<List<LessonModel>> fetchLessons() async {
    final response = await _supabase
        .from('lessons')
        .select()
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => LessonModel.fromJson(json))
        .toList();
  }

  // Obtener las lecciones creadas por un usuario en específico
  Future<List<LessonModel>> fetchLessonsByCreator(String creatorId) async {
    final response = await _supabase
        .from('lessons')
        .select()
        .eq('creator_id', creatorId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => LessonModel.fromJson(json))
        .toList();
  }
}

// Provider de lecciones globales
final lessonsListProvider = FutureProvider<List<LessonModel>>((ref) async {
  final service = ref.watch(lessonServiceProvider);
  return service.fetchLessons();
});

// Provider de lecciones creadas por un usuario
final userLessonsProvider = FutureProvider.autoDispose.family<List<LessonModel>, String>((ref, userId) async {
  final service = ref.watch(lessonServiceProvider);
  return service.fetchLessonsByCreator(userId);
});
