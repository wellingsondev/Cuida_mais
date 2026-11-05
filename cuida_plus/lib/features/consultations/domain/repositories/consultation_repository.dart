import '../entities/consultation.dart';

abstract class ConsultationRepository {
  Stream<List<Consultation>> watch(String patientId);
  Future<void> save(Consultation c);
  Future<void> delete(String id);
}
