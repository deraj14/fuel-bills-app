import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/bill.dart';

/// Wraps flutter_local_notifications to schedule a single reminder,
/// fired at 9:00 AM local time, one day before a bill's next due date.
///
/// IMPORTANT: because a bill repeats monthly and the "day before" shifts
/// month to month, each scheduled notification only covers the NEXT
/// occurrence. Call `NotificationService.rescheduleAll(bills)` whenever
/// the app starts and whenever the bill list changes, so the upcoming
/// cycle is always covered. Once scheduled, the OS will fire it even if
/// the app is fully closed or the phone is locked.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC if the platform can't report a timezone name.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  Future<void> scheduleBillReminder(Bill bill) async {
    await init();

    final due = bill.nextDueDate();
    final reminderDay = due.subtract(const Duration(days: 1));
    var reminderDateTime = tz.TZDateTime(
      tz.local,
      reminderDay.year,
      reminderDay.month,
      reminderDay.day,
      9, // 9:00 AM local time
    );

    // If that moment already passed today (edge case: bill due tomorrow,
    // added after 9am), fire in a few seconds instead of skipping it.
    final now = tz.TZDateTime.now(tz.local);
    if (reminderDateTime.isBefore(now)) {
      reminderDateTime = now.add(const Duration(seconds: 5));
    }

    const androidDetails = AndroidNotificationDetails(
      'bill_reminders',
      'Bill Due Reminders',
      channelDescription: 'Reminds you one day before a bill is due',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final typeLabel = bill.type == BillType.creditCard ? 'Credit card' : 'Utility';
    final amountStr = bill.amount != null ? ' · ₱${bill.amount!.toStringAsFixed(2)}' : '';

    await _plugin.zonedSchedule(
      bill.notificationId,
      'Due tomorrow: ${bill.name}',
      '$typeLabel bill due ${_fmt(due)}$amountStr',
      reminderDateTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelBillReminder(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  /// Cancels and re-schedules the reminder for every bill, so the
  /// upcoming month's occurrence is always covered. Call on app start
  /// and after any add/edit/delete of the bill list.
  Future<void> rescheduleAll(List<Bill> bills) async {
    await init();
    for (final bill in bills) {
      await scheduleBillReminder(bill);
    }
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}
