import '../../../medications/domain/usecases/build_daily_doses.dart';
import '../entities/med_log.dart';

abstract class HistoryRepository {
  Stream<List<MedLog>> watchLogs(String patientId, {DateTime? since, int limit = 200});
  Future<void> registerDose({required Dose dose, required DoseStatus status, required String actorUid, required String actorName});
}
