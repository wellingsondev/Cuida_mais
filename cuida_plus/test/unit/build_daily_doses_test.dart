import 'package:cuida_plus/features/history/domain/entities/med_log.dart';
import 'package:cuida_plus/features/medications/domain/entities/medication.dart';
import 'package:cuida_plus/features/medications/domain/usecases/build_daily_doses.dart';
import 'package:flutter_test/flutter_test.dart';

Medication med({String id = 'm1', bool active = true, DateTime? start, DateTime? end, bool reminders = true}) => Medication(
    id: id, patientId: 'p', name: 'Medicamento A', dosage: 'Conforme prescrição', startDate: start ?? DateTime(2025, 1, 1), endDate: end, active: active, remindersEnabled: reminders);
MedSchedule sched(int h, [int m = 0, String medId = 'm1']) =>
    MedSchedule(id: MedSchedule.idFor(medId, h, m), patientId: 'p', medicationId: medId, hour: h, minute: m);

void main() {
  final day = DateTime(2025, 6, 10);

  test('um medicamento com vários horários gera uma dose por horário, ordenadas', () {
    final doses = buildDailyDoses(day: day, meds: [med()], schedules: [sched(20), sched(8), sched(14)], logs: []);
    expect(doses.map((d) => d.schedule.hour), [8, 14, 20]);
  });
  test('medicamento inativo ou sem lembretes não gera doses', () {
    expect(buildDailyDoses(day: day, meds: [med(active: false)], schedules: [sched(8)], logs: []), isEmpty);
    expect(buildDailyDoses(day: day, meds: [med(reminders: false)], schedules: [sched(8)], logs: []), isEmpty);
  });
  test('respeita início e término do tratamento', () {
    final m = med(start: DateTime(2025, 6, 11), end: DateTime(2025, 6, 20));
    expect(buildDailyDoses(day: DateTime(2025, 6, 10), meds: [m], schedules: [sched(8)], logs: []), isEmpty);
    expect(buildDailyDoses(day: DateTime(2025, 6, 11), meds: [m], schedules: [sched(8)], logs: []), hasLength(1));
    expect(buildDailyDoses(day: DateTime(2025, 6, 20), meds: [m], schedules: [sched(8)], logs: []), hasLength(1));
    expect(buildDailyDoses(day: DateTime(2025, 6, 21), meds: [m], schedules: [sched(8)], logs: []), isEmpty);
  });
  test('ID do registro é determinístico (evita duplicidade) e associa o log existente', () {
    final s = sched(8);
    final id = s.logIdFor(day);
    expect(id, 'm1_0800_20250610');
    final log = MedLog(id: id, patientId: 'p', medicationId: 'm1', scheduleId: s.id, medicationName: 'Medicamento A', scheduledAt: day, status: DoseStatus.confirmed);
    final doses = buildDailyDoses(day: day, meds: [med()], schedules: [s], logs: [log]);
    expect(doses.single.status, DoseStatus.confirmed);
  });
  test('horário duplicado gera o mesmo ID de agendamento', () {
    expect(MedSchedule.idFor('m1', 8, 0), MedSchedule.idFor('m1', 8, 0));
  });
  test('dose pendente fica atrasada após a tolerância', () {
    final d = buildDailyDoses(day: day, meds: [med()], schedules: [sched(8)], logs: []).single;
    expect(d.isOverdue(DateTime(2025, 6, 10, 8, 10)), isFalse);
    expect(d.isOverdue(DateTime(2025, 6, 10, 8, 31)), isTrue);
  });
}
