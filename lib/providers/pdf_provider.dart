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

class CourseSemesterParams {
  final String course;
  final String semester;

  CourseSemesterParams({required this.course, required this.semester});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseSemesterParams &&
          runtimeType == other.runtimeType &&
          course == other.course &&
          semester == other.semester;

  @override
  int get hashCode => course.hashCode ^ semester.hashCode;
}

class CourseSemesterSubjectParams {
  final String course;
  final String semester;
  final String subject;

  CourseSemesterSubjectParams({
    required this.course,
    required this.semester,
    required this.subject,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseSemesterSubjectParams &&
          runtimeType == other.runtimeType &&
          course == other.course &&
          semester == other.semester &&
          subject == other.subject;

  @override
  int get hashCode => course.hashCode ^ semester.hashCode ^ subject.hashCode;
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

/// Provider for fetching available JNTU courses from jntu-mappings
final availableJntuCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final result = await ApiService.getAvailableJntuCourses();

  if (result['success'] == true) {
    return result['courses'] as List<Course>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch JNTU courses');
  }
});

/// Provider for fetching JNTU semesters by course
final jntuSemestersProvider = FutureProvider.family<List<String>, String>((ref, course) async {
  final result = await ApiService.getJntuSemestersByCourse(course);

  if (result['success'] == true) {
    return result['semesters'] as List<String>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch JNTU semesters');
  }
});

/// Provider for fetching JNTU subjects by course and semester
final jntuSubjectsProvider = FutureProvider.family<List<String>, CourseSemesterParams>((ref, params) async {
  final result = await ApiService.getJntuSubjectsByCourseAndSemester(params.course, params.semester);

  if (result['success'] == true) {
    return result['subjects'] as List<String>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch JNTU subjects');
  }
});

/// Provider for fetching JNTU files by course, semester and subject
final jntuFilesByCourseSubjectProvider = FutureProvider.family<List<PdfFile>, CourseSemesterSubjectParams>((ref, params) async {
  final result = await ApiService.getJntuFilesByCourseSemesterAndSubject(
    params.course,
    params.semester,
    params.subject,
  );

  if (result['success'] == true) {
    return result['files'] as List<PdfFile>;
  } else {
    throw Exception(result['message'] ?? 'Failed to fetch JNTU files');
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
