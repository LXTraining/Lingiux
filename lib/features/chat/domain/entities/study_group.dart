class StudyGroupModel {
  final String id;
  final String name;
  final String? description;
  final String creatorId;
  final String conversationId;
  final String growthType; // 'PLANT' o 'TAMAGOTCHI'
  final int growthPoints;
  final int level;
  final DateTime createdAt;

  const StudyGroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.creatorId,
    required this.conversationId,
    required this.growthType,
    required this.growthPoints,
    required this.level,
    required this.createdAt,
  });

  factory StudyGroupModel.fromJson(Map<String, dynamic> json) {
    return StudyGroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      creatorId: json['creator_id'] as String,
      conversationId: json['conversation_id'] as String,
      growthType: json['growth_type'] as String? ?? 'PLANT',
      growthPoints: json['growth_points'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'creator_id': creatorId,
      'conversation_id': conversationId,
      'growth_type': growthType,
      'growth_points': growthPoints,
      'level': level,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
