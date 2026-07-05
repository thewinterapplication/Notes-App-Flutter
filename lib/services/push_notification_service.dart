import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../screens/jobs_screen.dart';
import '../screens/resume_templates_screen.dart';
import '../screens/upskill_screen.dart';
import 'api_service.dart';

/// Must be a top-level function (FCM requirement) so it can run in the
/// background isolate. No work needed here — the OS already shows the tray
/// notification for background/killed app state when a `notification`
/// payload is present; this only needs to exist for FCM to deliver messages
/// while the app isn't running.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Wires up Firebase Cloud Messaging: requests permission, registers this
/// device's token with the backend, and shows a tray notification while the
/// app is in the foreground (FCM does not auto-display those).
class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'broadcast_notifications',
    'Announcements',
    description: 'New notes, syllabus, jobs and other updates',
    importance: Importance.high,
  );

  static bool _initialized = false;

  /// Safe to call on every login/app-start — one-time setup only runs once,
  /// the token registration always runs so a refreshed token stays in sync.
  static Future<void> init() async {
    if (!_initialized) {
      _initialized = true;
      await _initLocalNotifications();
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      FirebaseMessaging.instance.onTokenRefresh.listen(
        ApiService.registerFcmToken,
      );

      // Covers the cold-start case: app was fully closed and got launched by
      // tapping a notification. onMessageOpenedApp only fires for
      // background-to-foreground taps, not this one.
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleNotificationTap(initialMessage),
        );
      }
    }

    await _registerToken();
  }

  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _registerToken() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await ApiService.registerFcmToken(token);
    }
  }

  static Future<void> _showForegroundNotification(
    RemoteMessage message,
  ) async {
    final notification = message.notification;
    if (notification == null) return;

    final imageUrl = message.data['imageUrl'];
    StyleInformation? styleInformation;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      styleInformation = await _bigPictureStyleFor(imageUrl);
    }

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          // Gives every notification a bigger, more branded look even when
          // there's no per-content image (e.g. notes/JNTU/placement).
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: styleInformation,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Downloads the notification image for a full big-picture-style
  /// notification. Returns null (falling back to the default style) if the
  /// download fails, so a flaky image never prevents the notification from
  /// showing.
  static Future<StyleInformation?> _bigPictureStyleFor(String imageUrl) async {
    try {
      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      return BigPictureStyleInformation(
        ByteArrayAndroidBitmap(response.bodyBytes),
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );
    } catch (_) {
      return null;
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    switch (message.data['type']) {
      case 'job':
        navigator.push(MaterialPageRoute(builder: (_) => const JobsScreen()));
      case 'upskill':
        navigator.push(
          MaterialPageRoute(builder: (_) => const UpskillScreen()),
        );
      case 'resume':
        navigator.push(
          MaterialPageRoute(builder: (_) => const ResumeTemplatesScreen()),
        );
      default:
        // notes/jntu/placement: no single-document deep link exists yet, so
        // tapping just brings the app to the foreground (default behavior).
        break;
    }
  }
}
