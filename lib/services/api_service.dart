import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/broadcast_session.dart';
import '../models/resume_template.dart';
import '../models/course.dart';
import '../models/pdf_file.dart';
import '../models/subscription_checkout_session.dart';
import '../models/subscription_plan.dart';
import '../models/career_guidance_type.dart';

/// API Service to connect to server
class ApiService {
  // Single source of truth - use machine IP for all platforms
  // static const String baseUrl = 'https://notes-app-server-wczw.onrender.com';
  // static const String baseUrl = 'http://192.168.1.33:3000';
  static const String baseUrl = 'https://notes.codebinary.in';


  // Retry configuration for Render.com free tier (server may be sleeping)
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 3);
  static const Duration requestTimeout = Duration(seconds: 30);

  // --- Single-device session handling ---------------------------------------

  static const String _tokenKey = 'sessionId';
  static const String _deviceIdKey = 'deviceId';

  /// The active session token for this device. Sent as a Bearer token on every
  /// request. Cleared when the session is revoked (logged in elsewhere).
  static String? _sessionToken;

  /// A stable per-install identifier, shown to the user as the active device.
  static String? _deviceId;

  /// Invoked when the backend reports SESSION_REVOKED (this number logged in on
  /// another device). The auth layer registers this to force a logout + return
  /// to the login screen.
  static void Function()? onSessionRevoked;

  static String? get sessionToken => _sessionToken;
  static String? get deviceId => _deviceId;

  /// Load the persisted session token and device id. Call once at startup.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionToken = prefs.getString(_tokenKey);

    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = _generateDeviceId();
      await prefs.setString(_deviceIdKey, id);
    }
    _deviceId = id;
  }

  static Future<void> setSessionToken(String token) async {
    _sessionToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearSessionToken() async {
    _sessionToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static String _generateDeviceId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    final token = _sessionToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Inspect a response for a revoked session. Returns true if revoked so the
  /// caller can stop processing; also fires [onSessionRevoked] once.
  static bool _checkRevoked(http.Response response) {
    if (response.statusCode != 401) return false;
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['code'] == 'SESSION_REVOKED') {
        clearSessionToken();
        onSessionRevoked?.call();
        return true;
      }
    } catch (_) {
      // Non-JSON 401 — treat as a normal failure, not a forced logout.
    }
    return false;
  }

  // Helper method to make HTTP requests with retry logic
  static Future<http.Response> _postWithRetry(
    String url,
    Map<String, dynamic> body,
  ) async {
    Exception? lastError;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(requestTimeout);
        _checkRevoked(response);
        return response;
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
        final response = await http
            .get(Uri.parse(url), headers: _headers())
            .timeout(requestTimeout);
        _checkRevoked(response);
        return response;
      } catch (e) {
        lastError = e as Exception;
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt);
        }
      }
    }
    throw lastError ?? Exception('Request failed after $maxRetries attempts');
  }

  static Future<http.Response> _putWithRetry(
    String url,
    Map<String, dynamic> body,
  ) async {
    Exception? lastError;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .put(
              Uri.parse(url),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(requestTimeout);
        _checkRevoked(response);
        return response;
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
      final response = await _postWithRetry('$baseUrl/api/login', {
        'phone': phone,
        'deviceId': _deviceId,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Persist the single-device session token issued by the backend.
        final token = data['sessionId'] as String?;
        if (token != null && token.isNotEmpty) {
          await setSessionToken(token);
        }
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String phone,
  ) async {
    try {
      final response = await _postWithRetry('$baseUrl/api/register', {
        'name': name,
        'phone': phone,
        'deviceId': _deviceId,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['sessionId'] as String?;
        if (token != null && token.isNotEmpty) {
          await setSessionToken(token);
        }
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Send OTP to phone number
  static Future<Map<String, dynamic>> sendOTP(String phone) async {
    // Static test number bypass - skip OTP entirely
    if (phone == '9999999999') {
      return {'success': true, 'sessionId': 'test-session-9999999999'};
    }

    try {
      // Add country code for India if not present
      final phoneWithCode = phone.startsWith('91') ? phone : '91$phone';

      final response = await _postWithRetry('$baseUrl/otp/send', {
        'phoneNumber': phoneWithCode,
      });

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return {'success': true, 'sessionId': data['sessionId']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Verify OTP
  static Future<Map<String, dynamic>> verifyOTP(
    String sessionId,
    String otp,
  ) async {
    // Static test number bypass - accept OTP 5432
    if (sessionId == 'test-session-9999999999') {
      if (otp == '5432') {
        return {'success': true, 'message': 'OTP verified successfully'};
      }
      return {'success': false, 'message': 'Invalid OTP'};
    }

    try {
      final response = await _postWithRetry('$baseUrl/otp/verify', {
        'sessionId': sessionId,
        'otp': otp,
        'deviceId': _deviceId,
      });

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // For an existing user the backend already issues a session token here.
        final token = data['sessionId'] as String?;
        if (token != null && token.isNotEmpty) {
          await setSessionToken(token);
        }
        return {
          'success': true,
          'message': data['message'],
          'registered': data['registered'],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Invalid OTP'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
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
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
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
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch courses from mappings and keep only courses with at least one subject
  static Future<Map<String, dynamic>> getAvailableCourses() async {
    try {
      final response = await _getWithRetry('$baseUrl/api/mappings');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final mappings =
            (data['mappings'] as List? ?? const [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
        const courseGradientLoop = <List<Color>>[
          [Color(0xFF00838F), Color(0xFF006064)],
          [Color(0xFF1976D2), Color(0xFF0D47A1)],
          [Color(0xFF7B1FA2), Color(0xFF4A148C)],
          [Color(0xFFE91E8C), Color(0xFFC2185B)],
          [Color(0xFFE85D04), Color(0xFFD62828)],
        ];
        final filteredMappings =
            mappings
                .where(
                  (mapping) =>
                      (mapping['subjects'] as List? ?? const []).isNotEmpty,
                )
                .toList();
        final courses =
            List.generate(filteredMappings.length, (index) {
              final mapping = filteredMappings[index];
              final baseCourse = Course.fromAbbreviation(
                (mapping['course'] as String? ?? '').trim(),
              );
              final gradientColors =
                  courseGradientLoop[index % courseGradientLoop.length];

              return Course(
                id: baseCourse.id,
                abbreviation: baseCourse.abbreviation,
                fullName: baseCourse.fullName,
                icon: baseCourse.icon,
                gradientColors: gradientColors,
              );
            }).where((course) => course.abbreviation.isNotEmpty).toList();

        return {'success': true, 'courses': courses};
      } else {
        return {'success': false, 'message': 'Failed to fetch courses'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch PDF files by course and subject
  static Future<Map<String, dynamic>> getFilesByCourseAndSubject(
    String course,
    String subject,
  ) async {
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
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch courses from placement-mappings and keep only courses with at least one subject
  static Future<Map<String, dynamic>> getAvailablePlacementCourses() async {
    try {
      final response = await _getWithRetry('$baseUrl/api/placement-mappings');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final mappings =
            (data['mappings'] as List? ?? const [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
        const placementGradientLoop = <List<Color>>[
          [Color(0xFFE85D04), Color(0xFFD62828)],
          [Color(0xFFE91E8C), Color(0xFFC2185B)],
          [Color(0xFF7B1FA2), Color(0xFF4A148C)],
          [Color(0xFF1976D2), Color(0xFF0D47A1)],
          [Color(0xFF00838F), Color(0xFF006064)],
        ];
        final filteredMappings =
            mappings
                .where(
                  (mapping) =>
                      (mapping['subjects'] as List? ?? const []).isNotEmpty,
                )
                .toList();

        final courses =
            List.generate(filteredMappings.length, (index) {
              final mapping = filteredMappings[index];
              final baseCourse = Course.fromAbbreviation(
                (mapping['course'] as String? ?? '').trim(),
              );
              final gradientColors =
                  placementGradientLoop[index % placementGradientLoop.length];

              return Course(
                id: baseCourse.id,
                abbreviation: baseCourse.abbreviation,
                fullName: baseCourse.fullName,
                icon: baseCourse.icon,
                gradientColors: gradientColors,
              );
            }).where((course) => course.abbreviation.isNotEmpty).toList();

        return {'success': true, 'courses': courses};
      } else {
        return {'success': false, 'message': 'Failed to fetch placement courses'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch placement subjects for a course
  static Future<Map<String, dynamic>> getPlacementSubjectsByCourse(
    String course,
  ) async {
    try {
      final response = await _getWithRetry(
        '$baseUrl/api/placements/courses/${Uri.encodeComponent(course)}/subjects',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final subjects = List<String>.from(data['subjects'] ?? []);
        return {'success': true, 'subjects': subjects};
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch placement subjects',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch placement files by course and subject
  static Future<Map<String, dynamic>> getPlacementFilesByCourseAndSubject(
    String course,
    String subject,
  ) async {
    try {
      final response = await _getWithRetry(
        '$baseUrl/api/placements/courses/${Uri.encodeComponent(course)}/subjects/${Uri.encodeComponent(subject)}/files',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = (data['files'] as List)
            .map((json) => PdfFile.fromJson(json))
            .toList();
        return {'success': true, 'files': files};
      } else {
        return {'success': false, 'message': 'Failed to fetch placement files'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch placement files by subject (legacy)
  static Future<Map<String, dynamic>> getPlacementFilesBySubject(
    String subject,
  ) async {
    try {
      final response = await _getWithRetry(
        '$baseUrl/api/placements/files/subject/${Uri.encodeComponent(subject)}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = (data['files'] as List)
            .map((json) => PdfFile.fromJson(json))
            .toList();
        return {'success': true, 'files': files};
      } else {
        return {'success': false, 'message': 'Failed to fetch placement files'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch courses from jntu-mappings and keep only courses with at least one subject
  static Future<Map<String, dynamic>> getAvailableJntuCourses() async {
    try {
      final response = await _getWithRetry('$baseUrl/api/jntu-mappings');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final mappings =
            (data['mappings'] as List? ?? const [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
        const jntuGradientLoop = <List<Color>>[
          [Color(0xFF1565C0), Color(0xFF0D47A1)],
          [Color(0xFF00897B), Color(0xFF004D40)],
          [Color(0xFF7B1FA2), Color(0xFF4A148C)],
          [Color(0xFFE85D04), Color(0xFFD62828)],
          [Color(0xFFE91E8C), Color(0xFFC2185B)],
        ];
        final filteredMappings =
            mappings
                .where(
                  (mapping) =>
                      (mapping['semesters'] as List? ?? const []).any(
                        (semester) =>
                            ((semester as Map?)?['subjects'] as List? ??
                                    const [])
                                .isNotEmpty,
                      ),
                )
                .toList();

        final courses =
            List.generate(filteredMappings.length, (index) {
              final mapping = filteredMappings[index];
              final baseCourse = Course.fromAbbreviation(
                (mapping['course'] as String? ?? '').trim(),
              );
              final gradientColors =
                  jntuGradientLoop[index % jntuGradientLoop.length];

              return Course(
                id: baseCourse.id,
                abbreviation: baseCourse.abbreviation,
                fullName: baseCourse.fullName,
                icon: baseCourse.icon,
                gradientColors: gradientColors,
              );
            }).where((course) => course.abbreviation.isNotEmpty).toList();

        return {'success': true, 'courses': courses};
      } else {
        return {'success': false, 'message': 'Failed to fetch JNTU courses'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch JNTU semesters for a course
  static Future<Map<String, dynamic>> getJntuSemestersByCourse(
    String course,
  ) async {
    try {
      final response = await _getWithRetry(
        '$baseUrl/api/jntu/courses/${Uri.encodeComponent(course)}/semesters',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final semesters = List<String>.from(data['semesters'] ?? []);
        return {'success': true, 'semesters': semesters};
      } else {
        return {'success': false, 'message': 'Failed to fetch JNTU semesters'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch JNTU subjects for a course and semester
  static Future<Map<String, dynamic>> getJntuSubjectsByCourseAndSemester(
    String course,
    String semester,
  ) async {
    try {
      final response = await _getWithRetry(
        '$baseUrl/api/jntu/courses/${Uri.encodeComponent(course)}/semesters/${Uri.encodeComponent(semester)}/subjects',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final subjects = List<String>.from(data['subjects'] ?? []);
        return {'success': true, 'subjects': subjects};
      } else {
        return {'success': false, 'message': 'Failed to fetch JNTU subjects'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch JNTU files by course, semester and subject
  static Future<Map<String, dynamic>> getJntuFilesByCourseSemesterAndSubject(
    String course,
    String semester,
    String subject,
  ) async {
    try {
      final response = await _getWithRetry(
        '$baseUrl/api/jntu/courses/${Uri.encodeComponent(course)}/semesters/${Uri.encodeComponent(semester)}/subjects/${Uri.encodeComponent(subject)}/files',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = (data['files'] as List)
            .map((json) => PdfFile.fromJson(json))
            .toList();
        return {'success': true, 'files': files};
      } else {
        return {'success': false, 'message': 'Failed to fetch JNTU files'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch PYQ subjects for a course
  static Future<Map<String, dynamic>> getPyqSubjectsByCourse(
    String course,
  ) async {
    try {
      final response = await _getWithRetry(
        '$baseUrl/api/pyq/courses/${Uri.encodeComponent(course)}/subjects',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final subjects = List<String>.from(data['subjects'] ?? []);
        return {'success': true, 'subjects': subjects};
      } else {
        return {'success': false, 'message': 'Failed to fetch PYQ subjects'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch PYQ files by course and subject
  static Future<Map<String, dynamic>> getPyqFilesByCourseAndSubject(
    String course,
    String subject,
  ) async {
    try {
      final response = await _getWithRetry(
        '$baseUrl/api/pyq/courses/${Uri.encodeComponent(course)}/subjects/${Uri.encodeComponent(subject)}/files',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = (data['files'] as List)
            .map((json) => PdfFile.fromJson(json))
            .toList();
        return {'success': true, 'files': files};
      } else {
        return {'success': false, 'message': 'Failed to fetch PYQ files'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Fetch PYQ files by subject (legacy)
  static Future<Map<String, dynamic>> getPyqFilesBySubject(
    String subject,
  ) async {
    try {
      final response = await _getWithRetry(
        '$baseUrl/api/pyq/files/subject/${Uri.encodeComponent(subject)}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = (data['files'] as List)
            .map((json) => PdfFile.fromJson(json))
            .toList();
        return {'success': true, 'files': files};
      } else {
        return {'success': false, 'message': 'Failed to fetch PYQ files'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Get the logged-in user's profile (token-authenticated, includes favourites)
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await _getWithRetry('$baseUrl/api/user/profile');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch profile'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Confirm this device still holds the active session. Returns
  /// {'revoked': true} when another device has taken over (handled globally
  /// via onSessionRevoked, but exposed here for explicit checks).
  static Future<Map<String, dynamic>> checkSession() async {
    try {
      final response = await _getWithRetry('$baseUrl/api/session/check');
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'revoked': response.statusCode == 401};
    } catch (e) {
      // Network error — don't treat as revoked.
      return {'success': false, 'revoked': false};
    }
  }

  /// Tell the backend to clear this device's active session.
  static Future<void> logout() async {
    try {
      await _postWithRetry('$baseUrl/api/logout', {});
    } catch (_) {
      // Best-effort; the local token is cleared regardless.
    }
    await clearSessionToken();
  }

  /// Register/refresh this device's FCM token so the backend can send it
  /// broadcast push notifications. Best-effort — failures are swallowed so
  /// they never block login.
  static Future<void> registerFcmToken(String fcmToken) async {
    try {
      await _postWithRetry('$baseUrl/api/fcm/register-token', {
        'token': fcmToken,
      });
    } catch (_) {
      // Best-effort; a token-refresh retry will happen on the next app open.
    }
  }

  /// Fetch subscription plans configured on the backend
  static Future<Map<String, dynamic>> getSubscriptionPlans() async {
    try {
      final response = await _getWithRetry('$baseUrl/api/subscriptions/plans');
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final payload = (data['data'] as Map<String, dynamic>?) ?? const {};
        final plans = (payload['plans'] as List? ?? const [])
            .map(
              (item) => SubscriptionPlan.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
        final config =
            (payload['config'] as Map<String, dynamic>?)
                ?.cast<String, dynamic>() ??
            const {};

        return {'success': true, 'plans': plans, 'config': config};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to fetch plans',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Create a Razorpay subscription checkout session
  static Future<Map<String, dynamic>> createSubscriptionCheckout({
    required String phone,
    required String planCode,
  }) async {
    developer.log('[API] createSubscriptionCheckout: phone=$phone, planCode=$planCode', name: 'subscription');
    try {
      final response = await _postWithRetry(
        '$baseUrl/api/subscriptions/create',
        {'phone': phone, 'planCode': planCode},
      );

      developer.log('[API] createSubscriptionCheckout response: status=${response.statusCode}, body=${response.body}', name: 'subscription');

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true) {
        final payload = (data['data'] as Map<String, dynamic>?) ?? const {};
        final checkout = SubscriptionCheckoutSession.fromJson(
          Map<String, dynamic>.from((payload['checkout'] as Map?) ?? const {}),
        );
        final user =
            (payload['user'] as Map<String, dynamic>?)
                ?.cast<String, dynamic>() ??
            const {};

        developer.log('[API] Checkout session: subscriptionId=${checkout.subscriptionId}', name: 'subscription');
        return {
          'success': true,
          'checkout': checkout,
          'user': user,
          'message': data['message'],
        };
      }

      developer.log('[API] createSubscriptionCheckout failed: ${data['message']}', name: 'subscription');
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to start checkout',
        'data': data['data'],
      };
    } catch (e) {
      developer.log('[API] createSubscriptionCheckout exception: $e', name: 'subscription');
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Verify a successful subscription payment callback
  static Future<Map<String, dynamic>> verifySubscriptionPayment({
    required String phone,
    required String subscriptionId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final response =
          await _postWithRetry('$baseUrl/api/subscriptions/verify', {
            'phone': phone,
            'subscriptionId': subscriptionId,
            'paymentId': paymentId,
            'signature': signature,
          });

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = (data['data'] as Map<String, dynamic>?) ?? const {};
        return {
          'success': true,
          'user': (payload['user'] as Map<String, dynamic>?)
              ?.cast<String, dynamic>(),
          'message': data['message'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Verification failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Refresh subscription state from Razorpay
  static Future<Map<String, dynamic>> refreshSubscription(String phone) async {
    try {
      final response = await _postWithRetry(
        '$baseUrl/api/subscriptions/refresh',
        {'phone': phone},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = (data['data'] as Map<String, dynamic>?) ?? const {};
        return {
          'success': true,
          'user': (payload['user'] as Map<String, dynamic>?)
              ?.cast<String, dynamic>(),
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to refresh subscription',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Cancel an existing Razorpay subscription
  static Future<Map<String, dynamic>> cancelSubscription({
    required String phone,
    bool cancelAtCycleEnd = true,
  }) async {
    try {
      final response = await _postWithRetry(
        '$baseUrl/api/subscriptions/cancel',
        {'phone': phone, 'cancelAtCycleEnd': cancelAtCycleEnd},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = (data['data'] as Map<String, dynamic>?) ?? const {};
        return {
          'success': true,
          'user': (payload['user'] as Map<String, dynamic>?)
              ?.cast<String, dynamic>(),
          'message': data['message'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to cancel subscription',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
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

  /// Update the logged-in user's favourites (token-authenticated)
  static Future<Map<String, dynamic>> updateFavourites(
    List<String> favourites,
  ) async {
    try {
      final response = await _putWithRetry(
        '$baseUrl/api/user/favourites',
        {'favourites': favourites},
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final responseData = data['data'] as Map<String, dynamic>?;
        final favs = responseData?['favourites'] as List? ?? [];
        return {'success': true, 'favourites': List<String>.from(favs)};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update favourites',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
    }
  }

  /// Upload a PDF file
  static Future<Map<String, dynamic>> uploadFile({
    required File file,
    required String course,
    required String subject,
    required String author,
    String? customFileName,
    String accessType = 'free',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add the file
      final fileName = file.path.split(Platform.pathSeparator).last;
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
          contentType: MediaType('application', 'pdf'),
        ),
      );

      // Add form fields
      request.fields['course'] = course;
      request.fields['subject'] = subject;
      request.fields['author'] = author.trim();
      request.fields['accessType'] = accessType;
      if (customFileName != null && customFileName.isNotEmpty) {
        request.fields['customFileName'] = customFileName;
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          return {'success': false, 'message': data['error']};
        }
        return {
          'success': true,
          'url': data['url'],
          'fileName': data['fileName'],
          'id': data['id'],
        };
      } else {
        return {
          'success': false,
          'message': 'Upload failed with status ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Upload failed: ${e.toString()}'};
    }
  }

  /// Upload a JNTU syllabus PDF file
  static Future<Map<String, dynamic>> uploadJntuFile({
    required File file,
    required String course,
    required String semester,
    required String subject,
    required String author,
    String? customFileName,
    String accessType = 'free',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/upload-jntu');
      final request = http.MultipartRequest('POST', uri);

      // Add the file
      final fileName = file.path.split(Platform.pathSeparator).last;
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
          contentType: MediaType('application', 'pdf'),
        ),
      );

      // Add form fields
      request.fields['course'] = course;
      request.fields['semester'] = semester;
      request.fields['subject'] = subject;
      request.fields['author'] = author.trim();
      request.fields['accessType'] = accessType;
      if (customFileName != null && customFileName.isNotEmpty) {
        request.fields['customFileName'] = customFileName;
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          return {'success': false, 'message': data['error']};
        }
        return {
          'success': true,
          'url': data['url'],
          'fileName': data['fileName'],
          'id': data['id'],
        };
      } else {
        return {
          'success': false,
          'message': 'Upload failed with status ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Upload failed: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> createGuidanceRequest({
    required String userPhone,
    required DateTime scheduledAt,
    required String description,
  }) async {
    final res = await _postWithRetry('$baseUrl/api/guidance', {
      'userPhone': userPhone,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'description': description,
    });
    if (res.statusCode != 200) {
      throw Exception('Guidance request failed: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getMyGuidanceSessions({
    required String userPhone,
  }) async {
    developer.log('[API] getMyGuidanceSessions: phone=$userPhone');
    final res = await _getWithRetry(
      '$baseUrl/api/guidance/my?phone=${Uri.encodeComponent(userPhone)}',
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch sessions: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['sessions'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<List<CareerGuidanceType>> getCareerGuidanceTypes() async {
    developer.log('[API] getCareerGuidanceTypes');
    final res = await _getWithRetry('$baseUrl/api/career-types');
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch career types: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['types'] as List? ?? const []);
    return list
        .map((item) => CareerGuidanceType.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  static Future<Map<String, dynamic>> createGuidanceOrder({
    required String userPhone,
    required String typeSlug,
    required DateTime scheduledAt,
    required String description,
  }) async {
    developer.log('[API] createGuidanceOrder: phone=$userPhone, type=$typeSlug');
    final res = await _postWithRetry('$baseUrl/api/guidance/create-order', {
      'userPhone': userPhone,
      'typeSlug': typeSlug,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'description': description,
    });
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to create guidance order: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<ResumeTemplate>> getResumeTemplates() async {
    final res = await _getWithRetry('$baseUrl/api/resume-templates');
    if (res.statusCode != 200) throw Exception('Failed to fetch templates');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['templates'] as List? ?? const [])
        .map((item) => ResumeTemplate.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  static Future<List<BroadcastSession>> getBroadcastSessions() async {
    final res = await _getWithRetry('$baseUrl/api/broadcast');
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch broadcast sessions: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['sessions'] as List? ?? const [])
        .map((item) => BroadcastSession.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  static Future<Map<String, dynamic>> verifyGuidancePayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    developer.log('[API] verifyGuidancePayment: orderId=$orderId');
    final res = await _postWithRetry('$baseUrl/api/guidance/verify-payment', {
      'orderId': orderId,
      'paymentId': paymentId,
      'signature': signature,
    });
    if (res.statusCode != 200) {
      throw Exception('Payment verification failed: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
