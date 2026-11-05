import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // Request permissions for Android 13+
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();

      // Create notification channel with default sound
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'medicine_reminder',
        'Pengingat Obat',
        description: 'Notifikasi pengingat minum obat',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      await androidImplementation.createNotificationChannel(channel);
    }

    _initialized = true;
    debugPrint('✅ Notification Service initialized');
  }

  Future<void> scheduleNotification({
    required int id,
    required String medicineName,
    required String dosage,
    required DateTime scheduledTime,
  }) async {
    try {
      final now = DateTime.now();
      var notificationTime = scheduledTime;

      // If time has passed today, schedule for tomorrow
      if (notificationTime.isBefore(now)) {
        notificationTime = notificationTime.add(const Duration(days: 1));
      }

      // Convert to TZDateTime
      final tzTime = tz.TZDateTime.from(notificationTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'medicine_reminder',
        'Pengingat Obat',
        channelDescription: 'Notifikasi pengingat minum obat',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: Color(0xFF00BCD4),
        colorized: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        '⏰ Waktunya Minum Obat!',
        '💊 $medicineName ($dosage)',
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      );

      debugPrint(
        '✅ Notification scheduled for $medicineName at ${tzTime.toString()}',
      );
      debugPrint('   ID: $id');
      debugPrint('   Current time: ${tz.TZDateTime.now(tz.local)}');

      // Show immediate test notification
      if (notificationTime.difference(now).inMinutes < 2) {
        await showMedicineReminder(
          medicineName: medicineName,
          dosage: dosage,
          time:
              '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error scheduling notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint('🗑️ Notification cancelled: $id');
  }

  Future<void> showMedicineReminder({
    required String medicineName,
    required String dosage,
    required String time,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'medicine_reminder',
        'Pengingat Obat',
        channelDescription: 'Notifikasi pengingat minum obat',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: Color(0xFF00BCD4),
        colorized: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        '⏰ Waktunya Minum Obat!',
        '💊 $medicineName ($dosage) - Jadwal: $time',
        details,
      );

      await playNotificationSound();
      debugPrint('✅ Immediate notification shown for $medicineName');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  Future<void> playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      // Silently fail if sound file doesn't exist
      debugPrint('ℹ️ Sound file not found (optional)');
    }
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    debugPrint('🗑️ All notifications cancelled');
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}
