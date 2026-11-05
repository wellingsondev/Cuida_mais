import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../medications/domain/usecases/build_daily_doses.dart';
import '../../domain/entities/med_log.dart';
import '../../domain/repositories/history_repository.dart';

class FirestoreHistoryRepository implements HistoryRepository {
  FirestoreHistoryRepository(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<List<MedLog>> watchLogs(String patientId, {DateTime? since, int limit = 200}) {
    Query<Map<String, dynamic>> q = _db.collection('medication_logs').where('patientId', isEqualTo: patientId);
    if (since != null) q = q.where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    return q.orderBy('scheduledAt', descending: true).limit(limit).snapshots(includeMetadataChanges: true).map((s) => s.docs.map(MedLog.fromDoc).toList());
  }

  /// ID determinístico (horário + dia) => um único registro por ocorrência.
  /// set(merge) e batch funcionam offline (ao contrário de transações). Toda mudança
  /// gera uma entrada imutável em medication_logs/{id}/changes (autor, data, de/para).
  @override
  Future<void> registerDose({required Dose dose, required DoseStatus status, required String actorUid, required String actorName}) {
    final ref = _db.collection('medication_logs').doc(dose.logId);
    return guard(() {
      final batch = _db.batch();
      batch.set(ref, {
        'patientId': dose.medication.patientId, 'medicationId': dose.medication.id, 'scheduleId': dose.schedule.id,
        'medicationName': dose.medication.name, 'scheduledAt': Timestamp.fromDate(dose.scheduledAt),
        'status': status.value, 'confirmedAt': status == DoseStatus.confirmed ? FieldValue.serverTimestamp() : null,
        'actorUid': actorUid, 'actorName': actorName, 'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(ref.collection('changes').doc(), {
        'from': dose.log?.status.value, 'to': status.value, 'actorUid': actorUid, 'actorName': actorName, 'at': FieldValue.serverTimestamp(),
      });
      return batch.commit();
    }, write: true);
  }
}
