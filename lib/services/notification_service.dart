import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> showOverdueIntentsReminder(int count) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'intents_channel',
      'Commitments',
      channelDescription: 'Reminders for open commitments',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      silent: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      1,
      'SoulSync',
      count == 1
          ? 'You have 1 commitment waiting'
          : 'You have $count commitments waiting',
      details,
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
