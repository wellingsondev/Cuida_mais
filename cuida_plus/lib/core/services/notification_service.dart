import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/consultations/domain/entities/consultation.dart';
import '../../features/medications/domain/entities/medication.dart';
import '../utils/date_utils.dart';

/// Lembretes LOCAIS (funcionam com o app fechado). Notificações para familiares são
/// enviadas pelas Cloud Functions (FCM) — veja functions/index.js.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  String timezoneName = 'America/Sao_Paulo';
  String _lastSignature = '';
  Future<void> _queue = Future.value();

  static const _channel = AndroidNotificationDetails(
    'medication_reminders', 'Lembretes de medicamentos e consultas',
    channelDescription: 'Avisos nos horários cadastrados',
    importance: Importance.max, priority: Priority.high, category: AndroidNotificationCategory.reminder,
  );
  static const _details = NotificationDetails(android: _channel, iOS: DarwinNotificationDetails());

  /// ID estável (FNV-1a 31 bits): o mesmo item sempre gera o mesmo ID => sem duplicatas.
  static int stableId(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h & 0x7FFFFFFF;
  }

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final dynamic t = await FlutterTimezone.getLocalTimezone();
      timezoneName = t is String ? t : (t.identifier as String);
    } catch (_) {}
    try {
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      timezoneName = 'America/Sao_Paulo';
      tz.setLocalLocation(tz.getLocation(timezoneName));
    }
    await _plugin.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ));
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> requestPermission() async {
    final a = await _android?.requestNotificationsPermission();
    final i = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (a ?? i ?? true);
  }

  /// Alarmes exatos exigem permissão especial no Android 12+; sem ela usamos agendamento inexato.
  Future<void> requestExactAlarms() async => _android?.requestExactAlarmsPermission();

  Future<AndroidScheduleMode> _mode() async => (await _android?.canScheduleExactNotifications() ?? false)
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  Future<void> cancelAll() async {
    _lastSignature = '';
    await _plugin.cancelAll();
  }

  Future<void> showNow(String title, String body) =>
      _plugin.show(
          id: stableId('now_${DateTime.now().microsecondsSinceEpoch}'), title: title, body: body, notificationDetails: _details);

  Future<void> snooze(String logId, String medName, {int minutes = 15}) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    await _plugin.zonedSchedule(
        id: stableId('snooze_$logId'), title: 'Lembrete adiado', body: medName, scheduledDate: when,
        notificationDetails: _details, androidScheduleMode: await _mode());
  }

  /// Recalcula TODOS os agendamentos (cancela e recria). Serializado e idempotente.
  Future<void> syncAll({
    required List<Medication> meds,
    required List<MedSchedule> schedules,
    required List<Consultation> consultations,
  }) {
    final sig = [
      ...meds.map((m) => '${m.id}${m.name}${m.dosage}${m.generatesReminders}${m.startDate}${m.endDate}'),
      ...schedules.map((s) => '${s.id}${s.active}'),
      ...consultations.map((c) => '${c.id}${c.dateTime}${c.status}${c.reminderMinutes}'),
    ].join('|');
    if (sig == _lastSignature) return _queue;
    _lastSignature = sig;
    _queue = _queue.then((_) => _doSync(meds, schedules, consultations)).catchError((Object e) {
      _lastSignature = '';
      debugPrint('syncAll falhou');
    });
    return _queue;
  }

  Future<void> _doSync(List<Medication> meds, List<MedSchedule> schedules, List<Consultation> consultations) async {
    await _plugin.cancelAll();
    final mode = await _mode();
    final now = tz.TZDateTime.now(tz.local);
    final today = tz.TZDateTime(tz.local, now.year, now.month, now.day);
    final byMed = {for (final m in meds) m.id: m};

    for (final s in schedules) {
      final m = byMed[s.medicationId];
      if (m == null || !m.generatesReminders) continue;
      final start = tz.TZDateTime(tz.local, m.startDate.year, m.startDate.month, m.startDate.day);
      final base = start.isAfter(today) ? start : today;
      const title = 'Hora do medicamento';
      final body = '${m.name} — ${m.dosage} (${s.label})';

      if (m.endDate == null) {
        // Sem data final: repetição diária nativa.
        var first = tz.TZDateTime(tz.local, base.year, base.month, base.day, s.hour, s.minute);
        if (!first.isAfter(now)) first = tz.TZDateTime(tz.local, base.year, base.month, base.day + 1, s.hour, s.minute);
        await _plugin.zonedSchedule(
            id: stableId('med_${s.id}'), title: title, body: body, scheduledDate: first, notificationDetails: _details,
            androidScheduleMode: mode, matchDateTimeComponents: DateTimeComponents.time, payload: 'med:${s.id}');
      } else {
        // Com data final: um agendamento por dia até o término (limite de 60 dias por horário).
        final end = tz.TZDateTime(tz.local, m.endDate!.year, m.endDate!.month, m.endDate!.day, 23, 59);
        for (var i = 0; i < 60; i++) {
          final at = tz.TZDateTime(tz.local, base.year, base.month, base.day + i, s.hour, s.minute);
          if (at.isAfter(end)) break;
          if (!at.isAfter(now)) continue;
          await _plugin.zonedSchedule(
              id: stableId('med_${s.id}_${dateKey(at)}'), title: title, body: body, scheduledDate: at, notificationDetails: _details,
              androidScheduleMode: mode, payload: 'med:${s.id}');
        }
      }
    }

    for (final c in consultations) {
      if (c.status != 'scheduled') continue;
      final at = tz.TZDateTime.from(c.dateTime.subtract(Duration(minutes: c.reminderMinutes)), tz.local);
      if (!at.isAfter(now)) continue;
      await _plugin.zonedSchedule(
          id: stableId('consult_${c.id}'), title: 'Consulta próxima', body: '${c.professional} — ${fmtDateTime(c.dateTime)}',
          scheduledDate: at, notificationDetails: _details, androidScheduleMode: mode, payload: 'consult:${c.id}');
    }
  }
}
