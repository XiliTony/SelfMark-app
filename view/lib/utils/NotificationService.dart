import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 本地通知服务：番茄钟到点时提醒。
///
/// - 使用系统调度（zonedSchedule），锁屏/切后台也能准时提醒
/// - Android 使用非精确闹钟模式，避免申请精确闹钟权限
/// - Web 端直接跳过，不阻塞计时
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _pomodoroNotificationId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) {
      return;
    }
    try {
      tz_data.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings: settings);

      // Android 13+ 需要运行时授权；用户拒绝也不影响计时本身
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _initialized = true;
    } catch (_) {
      // 通知不可用（模拟器限制、权限、时区库异常）时静默降级：计时仍然可用
      _initialized = false;
    }
  }

  /// 在 [endAt] 时刻提醒本次 [label] 的专注结束。
  Future<void> schedulePomodoroEnd({
    required DateTime endAt,
    required String label,
  }) async {
    if (kIsWeb) {
      return;
    }
    await init();
    if (!_initialized) {
      return;
    }
    try {
      await _plugin.zonedSchedule(
        id: _pomodoroNotificationId,
        title: '专注完成',
        body: '$label 的专注时间结束了，休息一下吧。',
        scheduledDate: tz.TZDateTime.from(endAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'pomodoro_channel',
            '番茄钟提醒',
            channelDescription: '番茄钟倒计时结束时提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // 调度失败不打断计时
    }
  }

  /// 取消尚未触发的提醒（暂停/重置时调用）。
  Future<void> cancelPomodoroEnd() async {
    if (kIsWeb || !_initialized) {
      return;
    }
    try {
      await _plugin.cancel(id: _pomodoroNotificationId);
    } catch (_) {
      // ignore
    }
  }
}
