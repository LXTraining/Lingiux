import 'lesson_exercise_model.dart';

class LessonModel {
  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final String language;
  final String difficulty;
  final List<String> cardIds;
  final List<LessonExerciseModel> exercises;
  final DateTime createdAt;

  const LessonModel({
    required this.id,
    required this.creatorId,
    required this.title,
    this.description,
    required this.language,
    required this.difficulty,
    required this.cardIds,
    required this.exercises,
    required this.createdAt,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exercises'] as List? ?? [];
    final exercises = rawExercises
        .map((e) => LessonExerciseModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return LessonModel(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      language: json['language'] as String,
      difficulty: json['difficulty'] as String,
      cardIds: List<String>.from(json['card_ids'] ?? []),
      exercises: exercises,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_id': creatorId,
      'title': title,
      'description': description,
      'language': language,
      'difficulty': difficulty,
      'card_ids': cardIds,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
