import 'dart:math';
import '../../../vocabulary/domain/models/word_card_model.dart';
import '../models/lesson_exercise_model.dart';

class LessonCompiler {
  static List<LessonExerciseModel> compile({
    required List<WordCardModel> cards,
  }) {
    final List<LessonExerciseModel> exercises = [];
    final random = Random();

    // Palabras de distracción por si hay pocas cartas en la lección
    const genericDistractors = [
      'Hola', 'Adiós', 'Gracias', 'Por favor', 'Agua', 'Café', 'Manzana',
      'Libro', 'Perro', 'Gato', 'Casa', 'Escuela', 'Amigo', 'Familia', 'Tiempo'
    ];

    for (int i = 0; i < cards.length; i++) {
      final card = cards[i];
      final cardId = card.id;

      // 1. EJERCICIO 1: Selección Múltiple (Traducción)
      final optionsTranslation = <String>{card.definition};
      // Agregar traducciones de otras cartas seleccionadas
      for (final other in cards) {
        if (other.id != cardId) {
          optionsTranslation.add(other.definition);
        }
      }
      // Rellenar con distractores genéricos hasta tener 4 opciones
      int distractorIdx = 0;
      while (optionsTranslation.length < 4 && distractorIdx < genericDistractors.length) {
        optionsTranslation.add(genericDistractors[distractorIdx++]);
      }

      exercises.add(LessonExerciseModel(
        id: '${cardId}_trans',
        type: ExerciseType.multipleChoice,
        question: '¿Cuál es la traducción de "${card.word}"?',
        correctAnswer: card.definition,
        options: optionsTranslation.toList()..shuffle(random),
      ));

      // 2. EJERCICIO 2: Listening Quiz (Si tiene audio)
      if (card.audioUrl != null && card.audioUrl!.isNotEmpty) {
        final optionsListening = <String>{card.word};
        for (final other in cards) {
          if (other.id != cardId) {
            optionsListening.add(other.word);
          }
        }
        int lIdx = 0;
        while (optionsListening.length < 4 && lIdx < genericDistractors.length) {
          optionsListening.add(genericDistractors[lIdx++]);
        }

        exercises.add(LessonExerciseModel(
          id: '${cardId}_listen',
          type: ExerciseType.listeningQuiz,
          question: 'Escucha y selecciona la palabra correcta',
          audioUrl: card.audioUrl,
          correctAnswer: card.word,
          options: optionsListening.toList()..shuffle(random),
        ));
      }

      // 3. EJERCICIO 3: Ordenar Frase (Si tiene frase de ejemplo)
      if (card.exampleSentence != null && card.exampleSentence!.isNotEmpty) {
        // Limpiar signos de puntuación básicos para facilitar el ordenamiento
        final cleanSentence = card.exampleSentence!
            .replaceAll(RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()]'), '')
            .trim();
        final words = cleanSentence.split(RegExp(r'\s+'));

        if (words.length > 2) {
          final optionsBlocks = <String>{...words};
          // Añadir un par de distractores
          optionsBlocks.add('water');
          optionsBlocks.add('coffee');

          exercises.add(LessonExerciseModel(
            id: '${cardId}_sentence',
            type: ExerciseType.translateSentence,
            question: 'Ordena las palabras para formar la frase de ejemplo:',
            correctAnswer: cleanSentence,
            options: optionsBlocks.toList()..shuffle(random),
            correctSequence: words,
          ));
        }
      }

      // 4. EJERCICIO 4: Match de Pronunciación (Fonética)
      if (card.phonetic.isNotEmpty) {
        final optionsPhonetic = <String>{card.phonetic};
        for (final other in cards) {
          if (other.id != cardId && other.phonetic.isNotEmpty) {
            optionsPhonetic.add(other.phonetic);
          }
        }
        // Rellenar con fonéticas falsas
        final phoneticsBackup = ['/haʊ/', '/wɒt/', '/ðæts/', '/ðə/', '/aɪ/'];
        int pIdx = 0;
        while (optionsPhonetic.length < 4 && pIdx < phoneticsBackup.length) {
          optionsPhonetic.add(phoneticsBackup[pIdx++]);
        }

        exercises.add(LessonExerciseModel(
          id: '${cardId}_phonetic',
          type: ExerciseType.mnemonicMatch,
          question: '¿Cuál es la pronunciación correcta de "${card.word}"?',
          correctAnswer: card.phonetic,
          options: optionsPhonetic.toList()..shuffle(random),
        ));
      }
    }

    return exercises;
  }
}
