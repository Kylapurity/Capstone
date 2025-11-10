// services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Request POST_NOTIFICATIONS permission for Android 13+ (API 33+)
    if (Platform.isAndroid) {
      final androidInfo = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.getNotificationChannels();

      // Request notification permission for Android 13+
      final status = await Permission.notification.request();
      print(
        '📱 Android Notification Permission: ${status.isDenied
            ? "DENIED"
            : status.isGranted
            ? "GRANTED"
            : "RESTRICTED"}',
      );
    }

    // Initialize notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(initializationSettings);
    print('✓ Notification service initialized');
  }

  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'environmental_alerts',
          'Environmental Alerts',
          channelDescription:
              'Notifications for environmental issues on your poultry farm',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000, // Use timestamp as ID
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
