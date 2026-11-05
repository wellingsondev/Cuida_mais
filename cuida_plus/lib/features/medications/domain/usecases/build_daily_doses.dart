import '../../../history/domain/entities/med_log.dart';
import '../entities/medication.dart';

/// Uma ocorrência (medicamento + horário + dia) e seu registro, se existir.
class Dose {
  final Medication medication;
  final MedSchedule schedule;
  final DateTime day;
  final MedLog? log;
  const Dose({required this.medication, required this.schedule, required this.day, this.log});

  DateTime get scheduledAt => schedule.at(day);
  String get logId => schedule.logIdFor(day); // 1 registro por paciente/horário/dia => sem duplicidade
  DoseStatus get status => log?.status ?? DoseStatus.pending;
  bool isOverdue(DateTime now) =>
      status == DoseStatus.pending && now.isAfter(scheduledAt.add(const Duration(minutes: 30)));
}

List<Dose> buildDailyDoses({
  required DateTime day,
  required List<Medication> meds,
  required List<MedSchedule> schedules,
  required List<MedLog> logs,
}) {
  final byMed = {for (final m in meds) m.id: m};
  final logById = {for (final l in logs) l.id: l};
  final doses = <Dose>[];
  for (final s in schedules) {
    final m = byMed[s.medicationId];
    if (m == null || !m.generatesReminders || !m.isInTreatment(day)) continue;
    doses.add(Dose(medication: m, schedule: s, day: day, log: logById[s.logIdFor(day)]));
  }
  doses.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return doses;
}
