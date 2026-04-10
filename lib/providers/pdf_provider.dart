import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../models/pdf_file.dart';
import '../services/api_service.dart';

/// Provider for fetching available courses from mappings
final availableCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final result = await ApiService.getAvailableCourses();

  if (result['success'] == true) {
    return result['courses'] as List<Course>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch courses');
  }
});

/// Provider for fetching PDF files by course (legacy)
final pdfFilesProvider = FutureProvider.family<List<PdfFile>, String>((ref, subject) async {
  final result = await ApiService.getFilesBySubject(subject);

  if (result['success'] == true) {
    return result['files'] as List<PdfFile>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch files');
  }
});

/// Provider for fetching subjects by course
final subjectsProvider = FutureProvider.family<List<String>, String>((ref, course) async {
  final result = await ApiService.getSubjectsByCourse(course);

  if (result['success'] == true) {
    return result['subjects'] as List<String>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch subjects');
  }
});

/// Parameter class for course and subject combination
class CourseSubjectParams {
  final String course;
  final String subject;

  CourseSubjectParams({required this.course, required this.subject});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseSubjectParams &&
          runtimeType == other.runtimeType &&
          course == other.course &&
          subject == other.subject;

  @override
  int get hashCode => course.hashCode ^ subject.hashCode;
}

/// Provider for fetching PDF files by course and subject
final pdfFilesByCourseSubjectProvider = FutureProvider.family<List<PdfFile>, CourseSubjectParams>((ref, params) async {
  final result = await ApiService.getFilesByCourseAndSubject(params.course, params.subject);

  if (result['success'] == true) {
    return result['files'] as List<PdfFile>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch files');
  }
});

/// Provider for fetching available placement courses from placement-mappings
final availablePlacementCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final result = await ApiService.getAvailablePlacementCourses();

  if (result['success'] == true) {
    return result['courses'] as List<Course>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch placement courses');
  }
});

/// Provider for fetching placement subjects by course
final placementSubjectsProvider = FutureProvider.family<List<String>, String>((ref, course) async {
  final result = await ApiService.getPlacementSubjectsByCourse(course);

  if (result['success'] == true) {
    return result['subjects'] as List<String>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch placement subjects');
  }
});

/// Provider for fetching placement files by course and subject
final placementFilesByCourseSubjectProvider = FutureProvider.family<List<PdfFile>, CourseSubjectParams>((ref, params) async {
  final result = await ApiService.getPlacementFilesByCourseAndSubject(params.course, params.subject);

  if (result['success'] == true) {
    return result['files'] as List<PdfFile>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch placement files');
  }
});

/// Provider for fetching placement files by course (legacy)
final placementFilesProvider = FutureProvider.family<List<PdfFile>, String>((ref, subject) async {
  final result = await ApiService.getPlacementFilesBySubject(subject);

  if (result['success'] == true) {
    return result['files'] as List<PdfFile>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch placement files');
  }
});

/// Provider for fetching PYQ subjects by course
final pyqSubjectsProvider = FutureProvider.family<List<String>, String>((ref, course) async {
  final result = await ApiService.getPyqSubjectsByCourse(course);

  if (result['success'] == true) {
    return result['subjects'] as List<String>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch PYQ subjects');
  }
});

/// Provider for fetching PYQ files by course and subject
final pyqFilesByCourseSubjectProvider = FutureProvider.family<List<PdfFile>, CourseSubjectParams>((ref, params) async {
  final result = await ApiService.getPyqFilesByCourseAndSubject(params.course, params.subject);

  if (result['success'] == true) {
    return result['files'] as List<PdfFile>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch PYQ files');
  }
});

/// Provider for fetching PYQ files by course (legacy)
final pyqFilesProvider = FutureProvider.family<List<PdfFile>, String>((ref, subject) async {
  final result = await ApiService.getPyqFilesBySubject(subject);

  if (result['success'] == true) {
    return result['files'] as List<PdfFile>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch PYQ files');
  }
});
