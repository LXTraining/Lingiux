enum ExerciseType {
  listeningQuiz,      // ¿Qué escuchas? (Selección de audio)
  translateSentence,  // Traduce esta oración (Bloques de palabras)
  multipleChoice,     // Selección múltiple clásica
  mnemonicMatch       // Puzzle de nemotecnia
}

class LessonExerciseModel {
  final String id;
  final ExerciseType type;
  final String question;
  final String? audioUrl;
  final String correctAnswer;
  final List<String> options;
  final List<String>? correctSequence;

  const LessonExerciseModel({
    required this.id,
    required this.type,
    required this.question,
    this.audioUrl,
    required this.correctAnswer,
    required this.options,
    this.correctSequence,
  });

  factory LessonExerciseModel.fromJson(Map<String, dynamic> json) {
    return LessonExerciseModel(
      id: json['id'] as String,
      type: ExerciseType.values.firstWhere(
        (e) => e.name == (json['type'] as String),
        orElse: () => ExerciseType.multipleChoice,
      ),
      question: json['question'] as String,
      audioUrl: json['audio_url'] as String?,
      correctAnswer: json['correct_answer'] as String,
      options: List<String>.from(json['options'] ?? []),
      correctSequence: json['correct_sequence'] != null
          ? List<String>.from(json['correct_sequence'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'question': question,
      'audio_url': audioUrl,
      'correct_answer': correctAnswer,
      'options': options,
      'correct_sequence': correctSequence,
    };
  }
}
