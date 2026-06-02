import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../screens/my_community_posts_page.dart';
import '../screens/photogragher_bookings_screen.dart';
import '../screens/photographer_private_galleries_page.dart';
import '../screens/my_venues_page.dart';
import '../screens/photographer_dashboard.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  debugPrint("BACKGROUND PUSH TITLE: ${message.notification?.title}");
  debugPrint("BACKGROUND PUSH DATA: ${message.data}");
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static GlobalKey<NavigatorState>? _navigatorKey;

  static const String channelId = 'lensia_notifications';
  static const String channelName = 'Lensia Notifications';
  static const String channelDescription =
      'Booking, gallery, community, and order updates.';

  static const AndroidNotificationChannel androidChannel =
      AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.high,
    playSound: true,
  );

  static bool _initialized = false;

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static Future<void> _ensureFirebaseInitialized() async {
    if (kIsWeb) return;

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  static Future<void> init() async {
    if (kIsWeb) return;

    await _ensureFirebaseInitialized();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    if (_initialized) {
      await saveTokenToBackend();
      return;
    }

    await _requestPermission();
    await _initLocalNotifications();
    await saveTokenToBackend();

    _messaging.onTokenRefresh.listen((token) async {
      debugPrint("FCM TOKEN REFRESHED: $token");
      await _sendTokenToBackend(token);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint("FOREGROUND PUSH TITLE: ${message.notification?.title}");
      debugPrint("FOREGROUND PUSH DATA: ${message.data}");

      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Notification opened from background: ${message.data}");
      _handleNotificationTap(message.data);
    });

    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      debugPrint(
        "App opened from terminated notification: ${initialMessage.data}",
      );

      Future.delayed(const Duration(milliseconds: 700), () {
        _handleNotificationTap(initialMessage.data);
      });
    }

    _initialized = true;
  }

  static Future<void> _requestPermission() async {
    await _ensureFirebaseInitialized();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    debugPrint("FCM PERMISSION STATUS: ${settings.authorizationStatus}");
  }

  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;

        if (payload == null || payload.trim().isEmpty) return;

        try {
          final data = Map<String, dynamic>.from(jsonDecode(payload));
          _handleNotificationTap(data);
        } catch (e) {
          debugPrint("LOCAL NOTIFICATION PAYLOAD ERROR: $e");
        }
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(androidChannel);
    }
  }

  static Future<void> saveTokenToBackend() async {
    try {
      if (kIsWeb) return;

      await _ensureFirebaseInitialized();

      final token = await _messaging.getToken();

      debugPrint("FCM TOKEN: $token");

      if (token == null || token.trim().isEmpty) {
        debugPrint("FCM TOKEN IS EMPTY");
        return;
      }

      await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint("GET FCM TOKEN ERROR: $e");
    }
  }

  static Future<void> registerTokenWithBackend({
    String? fcmToken,
  }) async {
    try {
      if (kIsWeb) return;

      await _ensureFirebaseInitialized();

      final token = fcmToken ?? await _messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        debugPrint("REGISTER FCM TOKEN ERROR: token is empty");
        return;
      }

      await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint("REGISTER FCM TOKEN ERROR: $e");
    }
  }

  static Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      final authToken = await AuthService.getToken();

      if (authToken == null) {
        debugPrint("NO AUTH TOKEN, FCM TOKEN NOT SENT YET");
        return;
      }

      final deviceType = _deviceType();

      final newUrl = "${AuthService.apiBase}/notifications/fcm-token";
      final oldUrl = "${AuthService.apiBase}/fcm/token";

      final body = jsonEncode({
        "fcm_token": fcmToken,
        "device_type": deviceType,
      });

      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $authToken",
      };

      final response = await http.post(
        Uri.parse(newUrl),
        headers: headers,
        body: body,
      );

      debugPrint("SAVE FCM TOKEN NEW URL: $newUrl");
      debugPrint("SAVE FCM TOKEN STATUS: ${response.statusCode}");
      debugPrint("SAVE FCM TOKEN BODY: ${response.body}");

      if (response.statusCode == 200) return;

      final fallbackResponse = await http.post(
        Uri.parse(oldUrl),
        headers: headers,
        body: body,
      );

      debugPrint("SAVE FCM TOKEN OLD URL: $oldUrl");
      debugPrint("SAVE FCM TOKEN OLD STATUS: ${fallbackResponse.statusCode}");
      debugPrint("SAVE FCM TOKEN OLD BODY: ${fallbackResponse.body}");
    } catch (e) {
      debugPrint("SAVE FCM TOKEN ERROR: $e");
    }
  }

  static Future<void> deleteTokenFromBackend() async {
    try {
      if (kIsWeb) return;

      await _ensureFirebaseInitialized();

      final authToken = await AuthService.getToken();

      if (authToken == null) {
        debugPrint("DELETE FCM TOKEN: no auth token");
        return;
      }

      final fcmToken = await _messaging.getToken();

      if (fcmToken == null || fcmToken.trim().isEmpty) {
        debugPrint("DELETE FCM TOKEN: token is empty");
        return;
      }

      final newUrl = "${AuthService.apiBase}/notifications/fcm-token";

      final response = await http.delete(
        Uri.parse(newUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        body: jsonEncode({
          "fcm_token": fcmToken,
        }),
      );

      debugPrint("DELETE FCM TOKEN STATUS: ${response.statusCode}");
      debugPrint("DELETE FCM TOKEN BODY: ${response.body}");
    } catch (e) {
      debugPrint("DELETE FCM TOKEN ERROR: $e");
    }
  }

  static Future<void> _showForegroundNotification(
    RemoteMessage message,
  ) async {
    final notification = message.notification;

    final title =
        notification?.title ?? message.data["title"] ?? "Notification";

    final body = notification?.body ??
        message.data["body"] ??
        "You have a new update.";

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title.toString(),
      body: body.toString(),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static String _deviceType() {
    if (Platform.isAndroid) return "android";
    if (Platform.isIOS) return "ios";
    if (Platform.isMacOS) return "macos";
    if (Platform.isWindows) return "windows";
    return "unknown";
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data["type"]?.toString() ?? "";
    final referenceType = data["reference_type"]?.toString() ?? "";
    final referenceId = data["reference_id"]?.toString() ?? "";

    debugPrint("NOTIFICATION TAP TYPE: $type");
    debugPrint("NOTIFICATION TAP REF TYPE: $referenceType");
    debugPrint("NOTIFICATION TAP REF ID: $referenceId");

    final navigator = _navigatorKey?.currentState;

    if (navigator == null) {
      debugPrint("NOTIFICATION TAP: navigator is null");
      return;
    }

        if (_isCommunityType(type, referenceType)) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const MyCommunityPostsPage(),
        ),
      );
      return;
    }
    if (_isPhotographerType(type, referenceType)) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const PhotographerDashboard(),
        ),
      );
      return;
    }
    if (_isVenueType(type, referenceType)) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const MyVenuesPage(),
        ),
      );
      return;
    }

    if (referenceType == "booking_gallery") {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const PhotographerPrivateGalleriesPage(),
        ),
      );
      return;
    }

    if (type == "warehouse_order" || referenceType == "warehouse_order") {
      navigator.pushNamed("/warehouse-orders");
      return;
    }

    if (type == "booking" ||
        type == "booking_gallery" ||
        referenceType == "booking" ||
        referenceType == "photographer_booking" ||
        referenceType == "booking_gallery") {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const BookingsScreen(role: 'photographer'),
        ),
      );
      return;
    }

    debugPrint("NOTIFICATION TAP: no route configured for type=$type");
  }

  static bool _isCommunityType(String type, String referenceType) {
    return type.startsWith("community_") ||
        type == "community" ||
        type == "community_post_approved" ||
        type == "community_post_rejected" ||
        type == "community_post_hidden" ||
        type == "community_post_visible" ||
        type == "community_comment_hidden" ||
        type == "community_comment_visible" ||
        referenceType == "community_post" ||
        referenceType == "community_comment";
  }
    static bool _isVenueType(String type, String referenceType) {
    return referenceType == "venue" ||
        type == "venue_visible" ||
        type == "venue_hidden" ||
        type == "venue_reviewed" ||
        type == "venue_review_removed" ||
        type == "venue_flagged" ||
        type == "venue_flag_removed" ||
        type == "admin_venue_review";
  }
    static bool _isPhotographerType(String type, String referenceType) {
    return referenceType == "photographer" ||
        type == "photographer_visible" ||
        type == "photographer_hidden" ||
        type == "photographer_portfolio_reviewed" ||
        type == "photographer_portfolio_review_removed" ||
        type == "photographer_flagged" ||
        type == "photographer_flag_removed" ||
        type == "admin_photographer_review";
  }
}