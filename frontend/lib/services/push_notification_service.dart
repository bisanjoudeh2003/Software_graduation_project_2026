import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

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
  );

  static Future<void> init() async {
    if (kIsWeb) return;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _initLocalNotifications();
    await saveTokenToBackend();

    _messaging.onTokenRefresh.listen((token) async {
      await _sendTokenToBackend(token);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Notification opened from background: ${message.data}");
    });

    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      debugPrint(
        "App opened from terminated notification: ${initialMessage.data}",
      );
    }
  }

  static Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidInit,
    );

    await _localNotifications.initialize(
      settings: initSettings,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(androidChannel);
  }

  static Future<void> saveTokenToBackend() async {
    try {
      final token = await _messaging.getToken();

      if (token == null || token.isEmpty) {
        debugPrint("FCM TOKEN IS EMPTY");
        return;
      }

      await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint("GET FCM TOKEN ERROR: $e");
    }
  }

  static Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      final authToken = await AuthService.getToken();

      if (authToken == null) {
        debugPrint("NO AUTH TOKEN, FCM TOKEN NOT SENT YET");
        return;
      }

      final response = await http.post(
        Uri.parse("${AuthService.apiBase}/fcm/token"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        body: jsonEncode({
          "fcm_token": fcmToken,
          "device_type": "android",
        }),
      );

      debugPrint("SAVE FCM TOKEN STATUS: ${response.statusCode}");
      debugPrint("SAVE FCM TOKEN BODY: ${response.body}");
    } catch (e) {
      debugPrint("SAVE FCM TOKEN ERROR: $e");
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
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}