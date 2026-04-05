/// PDF File model matching backend schema
class PdfFile {
  final String id;
  final String fileName;
  final String course;
  final String subject;
  final String author;
  final String fileUrl;
  final String accessType;
  final int likesCount;
  final int viewCount;
  final DateTime createdAt;

  PdfFile({
    required this.id,
    required this.fileName,
    required this.course,
    required this.subject,
    required this.author,
    required this.fileUrl,
    required this.accessType,
    required this.likesCount,
    required this.viewCount,
    required this.createdAt,
  });

  factory PdfFile.fromJson(Map<String, dynamic> json) {
    final rawAccessType = (json['accessType']?.toString() ?? '')
        .trim()
        .toLowerCase();

    return PdfFile(
      id: json['_id'] ?? '',
      fileName: json['fileName'] ?? '',
      course: json['course'] ?? 'uncategorized',
      subject: json['subject'] ?? 'uncategorized',
      author: json['author']?.toString().trim() ?? '',
      fileUrl: json['fileUrl'] ?? '',
      accessType: rawAccessType == 'free' || rawAccessType == 'premium'
          ? rawAccessType
          : '',
      likesCount: json['likesCount'] ?? 0,
      viewCount: json['viewCount'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String get displayTitle {
    if (fileName.toLowerCase().endsWith('.pdf')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  String get displayAuthor {
    final value = author.trim();
    return value.isEmpty ? 'Unknown author' : value;
  }

  bool get isFree => accessType == 'free';
  bool get isPremium => accessType == 'premium';
  bool get hasAccessBadge => isFree || isPremium;
  String get accessLabel => isFree ? 'FREE' : isPremium ? 'PREMIUM' : '';
}
