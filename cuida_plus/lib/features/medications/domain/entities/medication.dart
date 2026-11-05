import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/date_utils.dart';

class Medication {
  final String id, patientId, name, dosage, form, notes;
  final DateTime startDate;
  final DateTime? endDate;
  final bool active, remindersEnabled, archived, pendingSync;
  const Medication({
    this.id = '', required this.patientId, required this.name, required this.dosage, this.form = '', this.notes = '',
    required this.startDate, this.endDate, this.active = true, this.remindersEnabled = true, this.archived = false, this.pendingSync = false,
  });

  /// Medicamentos inativos/arquivados ou com lembretes desligados não geram lembretes.
  bool get generatesReminders => active && remindersEnabled && !archived;

  /// Respeita início e término do tratamento (datas inclusivas).
  bool isInTreatment(DateTime day) {
    final d = dateOnly(day);
    if (d.isBefore(dateOnly(startDate))) return false;
    if (endDate != null && d.isAfter(dateOnly(endDate!))) return false;
    return true;
  }

  factory Medication.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return Medication(
      id: doc.id, patientId: m['patientId'], name: m['name'] ?? '', dosage: m['dosage'] ?? '', form: m['form'] ?? '', notes: m['notes'] ?? '',
      startDate: (m['startDate'] as Timestamp).toDate(), endDate: (m['endDate'] as Timestamp?)?.toDate(),
      active: m['active'] ?? true, remindersEnabled: m['remindersEnabled'] ?? true, archived: m['archived'] ?? false,
      pendingSync: doc.metadata.hasPendingWrites,
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId, 'name': name.trim(), 'dosage': dosage.trim(), 'form': form, 'notes': notes.trim(),
        'startDate': Timestamp.fromDate(dateOnly(startDate)), 'endDate': endDate == null ? null : Timestamp.fromDate(dateOnly(endDate!)),
        'active': active, 'remindersEnabled': remindersEnabled, 'archived': archived,
      };
}

/// Um horário diário de um medicamento. ID determinístico => sem horários duplicados.
class MedSchedule {
  final String id, patientId, medicationId, timezone;
  final int hour, minute;
  final bool active;
  const MedSchedule({required this.id, required this.patientId, required this.medicationId, required this.hour, required this.minute, this.timezone = 'America/Sao_Paulo', this.active = true});

  static String idFor(String medicationId, int h, int m) => '${medicationId}_${two(h)}${two(m)}';
  String get label => '${two(hour)}:${two(minute)}';
  DateTime at(DateTime day) => DateTime(day.year, day.month, day.day, hour, minute);
  String logIdFor(DateTime day) => '${id}_${dateKey(day)}';

  factory MedSchedule.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return MedSchedule(id: d.id, patientId: m['patientId'], medicationId: m['medicationId'], hour: m['hour'], minute: m['minute'],
        timezone: m['timezone'] ?? 'America/Sao_Paulo', active: m['active'] ?? true);
  }
}

typedef ScheduleTime = ({int hour, int minute});
