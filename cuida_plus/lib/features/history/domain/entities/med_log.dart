import 'package:cloud_firestore/cloud_firestore.dart';

enum DoseStatus {
  confirmed('confirmed', 'Confirmado pelo usuário'),
  pending('pending', 'Pendente'),
  notDone('not_done', 'Não realizado, conforme informado'),
  postponed('postponed', 'Adiado, conforme informado');

  const DoseStatus(this.value, this.label);
  final String value, label;
  static DoseStatus parse(String? v) => values.firstWhere((s) => s.value == v, orElse: () => pending);
}

/// Registro do que o USUÁRIO INFORMOU. Não é prova de ingestão do medicamento.
class MedLog {
  final String id, patientId, medicationId, scheduleId, medicationName, actorUid, actorName;
  final DateTime scheduledAt;
  final DoseStatus status;
  final DateTime? confirmedAt;
  final bool pendingSync;
  const MedLog({required this.id, required this.patientId, required this.medicationId, required this.scheduleId, required this.medicationName,
    required this.scheduledAt, required this.status, this.confirmedAt, this.actorUid = '', this.actorName = '', this.pendingSync = false});

  factory MedLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return MedLog(
      id: d.id, patientId: m['patientId'], medicationId: m['medicationId'] ?? '', scheduleId: m['scheduleId'] ?? '',
      medicationName: m['medicationName'] ?? '', scheduledAt: (m['scheduledAt'] as Timestamp).toDate(),
      status: DoseStatus.parse(m['status']), confirmedAt: (m['confirmedAt'] as Timestamp?)?.toDate(),
      actorUid: m['actorUid'] ?? '', actorName: m['actorName'] ?? '', pendingSync: d.metadata.hasPendingWrites,
    );
  }
}
