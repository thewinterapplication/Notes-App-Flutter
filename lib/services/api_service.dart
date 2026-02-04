import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pdf_file.dart';

/// API Service to connect to server
class ApiService {
  // Single source of truth - use machine IP for all platforms
  static const String baseUrl = 'https://notes-app-server-wczw.onrender.com';

  // Retry configuration for Render.com free tier (server may be sleeping)
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 3);
  static const Duration requestTimeout = Duration(seconds: 30);

  // Helper method to make HTTP requests with retry logic
  static Future<http.Response> _postWithRetry(String url, Map<String, dynamic> body) async {
    Exception? lastError;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(requestTimeout);
      } catch (e) {
        lastError = e as Exception;
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt);
        }
      }
    }
    throw lastError ?? Exception('Request failed after $maxRetries attempts');
  }

  static Future<http.Response> _getWithRetry(String url) async {
    Exception? lastError;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await http.get(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
        ).timeout(requestTimeout);
      } catch (e) {
        lastError = e as Exception;
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt);
        }
      }
    }
    throw lastError ?? Exception('Request failed after $maxRetries attempts');
  }

  static Future<http.Response> _putWithRetry(String url, Map<String, dynamic> body) async {
    Exception? lastError;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(requestTimeout);
      } catch (e) {
        lastError = e as Exception;
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt);
        }
      }
    }
    throw lastError ?? Exception('Request failed after $maxRetries attempts');
  }

  static Future<Map<String, dynamic>> login(String phone) async {
    try {
      final response = await _postWithRetry(
        '$baseUrl/api/login',
        {'phone': phone},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server is starting up. Please wait and try again.'};
    }
  }

  static Future<Map<String, dynamic>> register(String name, String phone) async {
    try {
      final response = await _postWithRetry(
        '$baseUrl/api/register',
        {'name': name, 'phone': phone},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server is starting up. Please wait and try again.'};
    }
  }

  /// Send OTP to phone number
  static Future<Map<String, dynamic>> sendOTP(String phone) async {
    try {
      // Add country code for India if not present
      final phoneWithCode = phone.startsWith('91') ? phone : '91$phone';

      final response = await _postWithRetry(
        '$baseUrl/otp/send',
        {'phoneNumber': phoneWithCode},
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return {'success': true, 'sessionId': data['sessionId']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to send OTP'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server is starting up. Please wait and try again.'};
    }
  }

  /// Verify OTP
  static Future<Map<String, dynamic>> verifyOTP(String sessionId, String otp) async {
    try {
      final response = await _postWithRetry(
        '$baseUrl/otp/verify',
        {'sessionId': sessionId, 'otp': otp},
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Invalid OTP'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server is starting up. Please wait and try again.'};
    }
  }

  /// Fetch PDF files by course (legacy - for backward compatibility)
  static Future<Map<String, dynamic>> getFilesBySubject(String subject) async {
    try {
      final response = await _getWithRetry(
        '$baseUrl/api/files/subject/${Uri.encodeComponent(subject)}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = (data['files'] as List)
            .map((json) => PdfFile.fromJson(json))
            .toList();
        return {'success': true, 'files': files};
      } else {
        return {'success': false, 'message': 'Failed to fetch files'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server is starting up. Please wait and try again.'};
    }
  }

  /// Fetch subjects for a course
  static Future<Map<String, dynamic>> getSubjectsByCourse(String course) async {
    try {
      final response = await _getWithRetry(
        '$baseUrl/api/courses/${Uri.encodeComponent(course)}/subjects',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final subjects = List<String>.from(data['subjects'] ?? []);
        return {'success': true, 'subjects': subjects};
      } else {
        return {'success': false, 'message': 'Failed to fetch subjects'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server is starting up. Please wait and try again.'};
    }
  }

  /// Fetch PDF files by course and subject
  static Future<Map<String, dynamic>> getFilesByCourseAndSubject(String course, String subject) async {
    try {
      final response = await _getWithRetry(
        '$baseUrl/api/courses/${Uri.encodeComponent(course)}/subjects/${Uri.encodeComponent(subject)}/files',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = (data['files'] as List)
            .map((json) => PdfFile.fromJson(json))
            .toList();
        return {'success': true, 'files': files};
      } else {
        return {'success': false, 'message': 'Failed to fetch files'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server is starting up. Please wait and try again.'};
    }
  }

  /// Get user profile (includes favourites)
  static Future<Map<String, dynamic>> getUserProfile(String phone) async {
    try {
      final response = await _getWithRetry('$baseUrl/api/user/$phone');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch profile'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server is starting up. Please wait and try again.'};
    }
  }

  /// Increment view count for a file
  static Future<void> incrementViewCount(String fileId) async {
    try {
      await _postWithRetry('$baseUrl/api/files/$fileId/view', {});
    } catch (_) {
      // Fire-and-forget
    }
  }

  /// Update user favourites
  static Future<Map<String, dynamic>> updateFavourites(String phone, List<String> favourites) async {
    try {
      final response = await _putWithRetry(
        '$baseUrl/api/user/$phone/favourites',
        {'favourites': favourites},
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final responseData = data['data'] as Map<String, dynamic>?;
        final favs = responseData?['favourites'] as List? ?? [];
        return {'success': true, 'favourites': List<String>.from(favs)};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to update favourites'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server is starting up. Please wait and try again.'};
    }
  }
}
