class ResumeTemplate {
  final String id;
  final String name;
  final String description;
  final String fileUrl;
  final String thumbnailUrl;
  final String fileType;
  final int sortOrder;

  const ResumeTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.fileUrl,
    required this.thumbnailUrl,
    required this.fileType,
    required this.sortOrder,
  });

  bool get isPdf => fileType == 'pdf';

  factory ResumeTemplate.fromJson(Map<String, dynamic> json) {
    return ResumeTemplate(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      fileUrl: (json['fileUrl'] ?? '') as String,
      thumbnailUrl: (json['thumbnailUrl'] ?? '') as String,
      fileType: (json['fileType'] ?? 'pdf') as String,
      sortOrder: (json['sortOrder'] ?? 0) as int,
    );
  }
}
