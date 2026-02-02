import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pdf_file.dart';
import '../services/api_service.dart';

/// Provider for fetching PDF files by course/subject
final pdfFilesProvider = FutureProvider.family<List<PdfFile>, String>((ref, subject) async {
  final result = await ApiService.getFilesBySubject(subject);

  if (result['success'] == true) {
    return result['files'] as List<PdfFile>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch files');
  }
});
