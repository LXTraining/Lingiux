class WordCardModel {
  final String id;
  final String word;
  final String definition;
  final String phonetic;
  final String imageUrl;
  final DateTime createdAt;

  const WordCardModel({
    required this.id,
    required this.word,
    required this.definition,
    required this.phonetic,
    required this.imageUrl,
    required this.createdAt,
  });

  factory WordCardModel.fromJson(Map<String, dynamic> json) {
    return WordCardModel(
      id: json['id'] as String,
      word: json['word'] as String,
      definition: json['definition'] as String,
      phonetic: json['phonetic'] as String,
      imageUrl: json['image_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
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
    };
  }
}
