/// PDF File model matching backend schema
class PdfFile {
  final String id;
  final String fileName;
  final String course;
  final String subject;
  final String fileUrl;
  final int likesCount;
  final int viewCount;
  final DateTime createdAt;

  PdfFile({
    required this.id,
    required this.fileName,
    required this.course,
    required this.subject,
    required this.fileUrl,
    required this.likesCount,
    required this.viewCount,
    required this.createdAt,
  });

  factory PdfFile.fromJson(Map<String, dynamic> json) {
    return PdfFile(
      id: json['_id'] ?? '',
      fileName: json['fileName'] ?? '',
      course: json['course'] ?? 'uncategorized',
      subject: json['subject'] ?? 'uncategorized',
      fileUrl: json['fileUrl'] ?? '',
      likesCount: json['likesCount'] ?? 0,
      viewCount: json['viewCount'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
