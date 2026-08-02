import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 1. تهيئة خدمة الإشعارات وتحديد المنطقة الزمنية
  static Future<void> init() async {
    tz.initializeTimeZones();
    // ضبط المنطقة الزمنية (تلقائياً على توقيت الرياض / السعودية)
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  // 2. طلب صلاحيات الإشعارات (مهم لأجهزة أندرويد 13+ و iOS)
  static Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // 3. جدولة إشعار الأذان لكل صلاة (تم تعديل الاسم ليطابق main.dart)
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    // التأكد من أن وقت الإشعار في المستقبل ولم يمر بعد
    if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_channel',
          'إشعارات الصلوات',
          channelDescription: 'إشعارات للتنبيه بمواعيد الأذان والصلاة',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 4. جدولة تذكير يوم الجمعة (قبل صلاة الظهر/الجمعة بساعة)
  static Future<void> scheduleFridayReminder(DateTime dhuhrTime) async {
    if (dhuhrTime.weekday == DateTime.friday) {
      final reminderTime = dhuhrTime.subtract(const Duration(hours: 1));
      final tzTime = tz.TZDateTime.from(reminderTime, tz.local);

      if (tzTime.isAfter(tz.TZDateTime.now(tz.local))) {
        await _notificationsPlugin.zonedSchedule(
          99,
          'تذكير يوم الجمعة 🕌',
          'باقي ساعة على صلاة الجمعة، لا تنس قراءة سورة الكهف والصلاة على النبي ﷺ',
          tzTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'friday_channel',
              'تنبيهات يوم الجمعة',
              channelDescription: 'تذكير بسُنن صلاة الجمعة',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  // 5. إلغاء جميع الإشعارات
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
