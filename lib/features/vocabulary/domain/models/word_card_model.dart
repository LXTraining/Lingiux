class WordCardModel {
  final String id;
  final String word;
  final String definition;
  final String phonetic;
  final String imageUrl;
  final DateTime createdAt;
  final String? exampleSentence;
  final String? category;
  final String? language;
  final String? audioUrl;
  final String? userId;

  const WordCardModel({
    required this.id,
    required this.word,
    required this.definition,
    required this.phonetic,
    required this.imageUrl,
    required this.createdAt,
    this.exampleSentence,
    this.category,
    this.language,
    this.audioUrl,
    this.userId,
  });

  factory WordCardModel.fromJson(Map<String, dynamic> json) {
    return WordCardModel(
      id: json['id'] as String,
      word: json['word'] as String,
      definition: json['definition'] as String,
      phonetic: json['phonetic'] as String,
      imageUrl: json['image_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      exampleSentence: json['example_sentence'] as String?,
      category: json['category'] as String?,
      language: json['language'] as String?,
      audioUrl: json['audio_url'] as String?,
      userId: json['user_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'definition': definition,
      'phonetic': phonetic,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'example_sentence': exampleSentence,
      'category': category,
      'language': language,
      'audio_url': audioUrl,
      'user_id': userId,
    };
  }
}
