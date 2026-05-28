class BroadcastSession {
  final String id;
  final String title;
  final String description;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String meetLink;
  final bool isActive;

  const BroadcastSession({
    required this.id,
    required this.title,
    required this.description,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.meetLink,
    required this.isActive,
  });

  factory BroadcastSession.fromJson(Map<String, dynamic> json) {
    return BroadcastSession(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      durationMinutes: (json['durationMinutes'] ?? 60) as int,
      meetLink: (json['meetLink'] ?? '') as String,
      isActive: (json['isActive'] ?? true) as bool,
    );
  }
}
