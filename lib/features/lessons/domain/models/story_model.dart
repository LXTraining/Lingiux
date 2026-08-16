class StoryModel {
  final String id;
  final String creatorId;
  final String title;
  final String content;
  final String language;
  final String difficulty;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const StoryModel({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.content,
    required this.language,
    required this.difficulty,
    required this.metadata,
    required this.createdAt,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      language: json['language'] as String? ?? 'EN',
      difficulty: json['difficulty'] as String? ?? 'A1',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_id': creatorId,
      'title': title,
      'content': content,
      'language': language,
      'difficulty': difficulty,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
