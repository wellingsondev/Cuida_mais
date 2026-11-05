import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/consultation.dart';
import '../../domain/repositories/consultation_repository.dart';

class FirestoreConsultationRepository implements ConsultationRepository {
  FirestoreConsultationRepository(this._db);
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('consultations');

  @override
  Stream<List<Consultation>> watch(String patientId) => _col
      .where('patientId', isEqualTo: patientId)
      .orderBy('dateTime')
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.docs.map(Consultation.fromDoc).toList());

  @override
  Future<void> save(Consultation c) => guard(() {
        final data = c.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
        if (c.id.isEmpty) return _col.add(data..['createdAt'] = FieldValue.serverTimestamp());
        return _col.doc(c.id).update(data);
      }, write: true);

  @override
  Future<void> delete(String id) => guard(() => _col.doc(id).delete(), write: true);
}
