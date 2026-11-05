import '../entities/medication.dart';

abstract class MedicationRepository {
  Stream<List<Medication>> watchMedications(String patientId);
  Stream<List<MedSchedule>> watchSchedules(String patientId);
  Future<String> save(Medication med, List<ScheduleTime> times, String timezone);
  Future<void> setActive(Medication med, bool active);
  Future<void> setReminders(Medication med, bool enabled);
  Future<void> archive(Medication med);
  Future<void> delete(Medication med);
}
