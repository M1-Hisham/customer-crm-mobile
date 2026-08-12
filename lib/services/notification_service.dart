import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Notification tapped handler
      },
    );

    _initialized = true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'hajjaj_crm_channel',
      'تنبيهات منصة حجاج المحاماة',
      channelDescription: 'قناة التنبيهات المباشرة للجلسات والأحكام والمهام',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  /// Check appointments list and trigger local notifications for upcoming hearings & judgment alerts
  Future<void> syncAppointmentsNotifications(List dynamicAppointments) async {
    await initialize();
    final now = DateTime.now();

    for (int i = 0; i < dynamicAppointments.length; i++) {
      final appt = dynamicAppointments[i];
      try {
        final DateTime apptDate = DateTime.parse(appt.date);
        final Duration diff = apptDate.difference(now);

        // If appointment is tomorrow or today within 24h
        if (diff.inHours > 0 && diff.inHours <= 24) {
          await showNotification(
            id: 1000 + i,
            title: '⏰ تذكير بموعد جلسة قادمة غداً/اليوم',
            body: 'جلسة: ${appt.title} في ${appt.court} | الساعة ${apptDate.hour}:${apptDate.minute.toString().padLeft(2, '0')}',
          );
        }

        // If appointment has a judgment with deed objection deadline
        if (appt.sessionResult == 'judgment' && appt.deedObjectionDeadline != null && appt.deedObjectionDeadline.toString().isNotEmpty) {
          await showNotification(
            id: 2000 + i,
            title: '⚠️ تنبيه حكم - مهلة الاعتراض 30 يوماً',
            body: 'صك رقم ${appt.deedNumber ?? ""} | آخر موعد للاعتراض: ${appt.deedObjectionDeadline}',
          );
        }
      } catch (_) {}
    }
  }
}
