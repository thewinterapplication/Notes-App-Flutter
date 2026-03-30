import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/pdf_file.dart';
import '../models/subscription_checkout_session.dart';
import '../models/subscription_plan.dart';

/// API Service to connect to server
class ApiService {
  // Single source of truth - use machine IP for all platforms
  static const String baseUrl = 'https://notes-app-server-wczw.onrender.com';
  // static const String baseUrl = 'http://10.142.181.35 `:3000';

  // Retry configuration for Render.com free tier (server may be sleeping)
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 3);
  static const Duration requestTimeout = Duration(seconds: 30);

  // Helper method to make HTTP requests with retry logic
  static Future<http.Response> _postWithRetry(
    String url,
    Map<String, dynamic> body,
  ) async {
    Exception? lastError;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(requestTimeout);
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
        return await http
            .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
            .timeout(requestTimeout);
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
        return await http
            .put(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(requestTimeout);
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
      });

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
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
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
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
      });

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return {'success': true, 'message': data['message']};
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
      return {
        'success': false,
        'message': 'Server is starting up. Please wait and try again.',
      };
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

  /// Update user favourites
  static Future<Map<String, dynamic>> updateFavourites(
    String phone,
    List<String> favourites,
  ) async {
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
    String? customFileName,
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
}
