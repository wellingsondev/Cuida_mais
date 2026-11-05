import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/medication.dart';
import '../../domain/repositories/medication_repository.dart';

class FirestoreMedicationRepository implements MedicationRepository {
  FirestoreMedicationRepository(this._db);
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _meds => _db.collection('medications');
  CollectionReference<Map<String, dynamic>> get _scheds => _db.collection('medication_schedules');

  @override
  Stream<List<Medication>> watchMedications(String patientId) => _meds
      .where('patientId', isEqualTo: patientId)
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.docs.map(Medication.fromDoc).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));

  @override
  Stream<List<MedSchedule>> watchSchedules(String patientId) => _scheds
      .where('patientId', isEqualTo: patientId)
      .snapshots()
      .map((s) => s.docs.map(MedSchedule.fromDoc).toList()..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute)));

  @override
  Future<String> save(Medication med, List<ScheduleTime> times, String timezone) {
    final ref = med.id.isEmpty ? _meds.doc() : _meds.doc(med.id);
    final isNew = med.id.isEmpty;
    return guard(() async {
      final batch = _db.batch();
      final data = med.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
      if (isNew) {
        data['createdAt'] = FieldValue.serverTimestamp();
        batch.set(ref, data);
      } else {
        batch.update(ref, data);
      }
      final existing = isNew
          ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
          : (await _scheds.where('patientId', isEqualTo: med.patientId).where('medicationId', isEqualTo: ref.id).get()).docs;
      final keep = <String>{};
      for (final t in times) {
        final id = MedSchedule.idFor(ref.id, t.hour, t.minute);
        keep.add(id);
        batch.set(_scheds.doc(id), {
          'patientId': med.patientId, 'medicationId': ref.id, 'hour': t.hour, 'minute': t.minute, 'timezone': timezone,
          'active': med.generatesReminders, 'startDateKey': dateKey(med.startDate),
          'endDateKey': med.endDate == null ? null : dateKey(med.endDate!), 'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      for (final d in existing) {
        if (!keep.contains(d.id)) batch.delete(d.reference);
      }
      await batch.commit();
      return ref.id;
    }, write: true).then((_) => ref.id);
  }

  Future<void> _flags(Medication m, {bool? active, bool? reminders, bool? archived}) => guard(() async {
        final a = active ?? m.active, r = reminders ?? m.remindersEnabled, ar = archived ?? m.archived;
        final batch = _db.batch();
        batch.update(_meds.doc(m.id), {'active': a, 'remindersEnabled': r, 'archived': ar, 'updatedAt': FieldValue.serverTimestamp()});
        final qs = await _scheds.where('patientId', isEqualTo: m.patientId).where('medicationId', isEqualTo: m.id).get();
        for (final d in qs.docs) {
          batch.update(d.reference, {'active': a && r && !ar, 'updatedAt': FieldValue.serverTimestamp()});
        }
        await batch.commit();
      }, write: true);

  @override
  Future<void> setActive(Medication m, bool active) => _flags(m, active: active);
  @override
  Future<void> setReminders(Medication m, bool enabled) => _flags(m, reminders: enabled);
  @override
  Future<void> archive(Medication m) => _flags(m, active: false, archived: true);

  /// Exclusão definitiva do medicamento e horários. O histórico (logs) é preservado.
  @override
  Future<void> delete(Medication m) => guard(() async {
        final batch = _db.batch();
        final qs = await _scheds.where('patientId', isEqualTo: m.patientId).where('medicationId', isEqualTo: m.id).get();
        for (final d in qs.docs) {
          batch.delete(d.reference);
        }
        batch.delete(_meds.doc(m.id));
        await batch.commit();
      }, write: true);
}
