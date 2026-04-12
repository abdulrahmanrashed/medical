import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/backend_models.dart';

/// Local notifications for [ApiAppointmentPrescription] lines (interval from [ApiAppointmentPrescription.timesPerDay]).
class MedicationReminderService {
  MedicationReminderService._();

  static final MedicationReminderService instance = MedicationReminderService._();

  static const _prefsDisabledIds = 'med_reminder_disabled_rx_ids';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    const channel = AndroidNotificationChannel(
      'medication_reminders',
      'Medication reminders',
      description: 'Scheduled doses from your prescriptions',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _ready = true;
  }

  Future<bool> isReminderEnabled(int prescriptionId) async {
    final p = await SharedPreferences.getInstance();
    final disabled = p.getStringList(_prefsDisabledIds) ?? const [];
    return !disabled.contains(prescriptionId.toString());
  }

  Future<void> setReminderEnabled(int prescriptionId, bool enabled) async {
    final p = await SharedPreferences.getInstance();
    final set = {...?p.getStringList(_prefsDisabledIds)};
    if (enabled) {
      set.remove(prescriptionId.toString());
    } else {
      set.add(prescriptionId.toString());
    }
    await p.setStringList(_prefsDisabledIds, set.toList());
  }

  /// Cancels then re-schedules enabled items (e.g. after loading medical history).
  Future<void> syncAppointmentPrescriptions(List<ApiAppointmentPrescription> items) async {
    await init();
    for (final rx in items) {
      final on = await isReminderEnabled(rx.id);
      if (on) {
        await schedulePrescription(rx);
      } else {
        await cancelPrescriptionNotifications(rx.id, rx.timesPerDay);
      }
    }
  }

  Future<void> schedulePrescription(ApiAppointmentPrescription p) async {
    await init();
    await cancelPrescriptionNotifications(p.id, p.timesPerDay);

    final now = DateTime.now().toUtc();
    if (p.endDateUtc != null && p.endDateUtc!.isBefore(now)) {
      return;
    }

    final n = p.timesPerDay.clamp(1, 24);
    final stepHours = (24 / n).floor().clamp(1, 24);

    for (var i = 0; i < n; i++) {
      final hour = (stepHours * i) % 24;
      final id = _notificationId(p.id, i);
      final when = _nextInstanceOfTime(hour, 0);
      await _plugin.zonedSchedule(
        id,
        p.medicationName,
        p.dosage.isNotEmpty ? p.dosage : 'Time to take your medication',
        when,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication reminders',
            channelDescription: 'Scheduled doses from your prescriptions',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelPrescriptionNotifications(int prescriptionId, int timesPerDay) async {
    await init();
    final n = timesPerDay.clamp(1, 24);
    for (var i = 0; i < n; i++) {
      await _plugin.cancel(_notificationId(prescriptionId, i));
    }
  }

  int _notificationId(int prescriptionId, int slot) => prescriptionId * 64 + slot;

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final loc = tz.local;
    final now = tz.TZDateTime.now(loc);
    var scheduled =
        tz.TZDateTime(loc, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
