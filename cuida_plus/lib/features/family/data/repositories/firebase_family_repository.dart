import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/family.dart';
import '../../domain/repositories/family_repository.dart';

class FirebaseFamilyRepository implements FamilyRepository {
  FirebaseFamilyRepository(this._db, this._fn);
  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;
  CollectionReference<Map<String, dynamic>> get _rel => _db.collection('family_relationships');

  @override
  Stream<List<FamilyRelationship>> watchAsPatient(String id) =>
      _rel.where('patientId', isEqualTo: id).snapshots().map((s) => s.docs.map(FamilyRelationship.fromDoc).toList());
  @override
  Stream<List<FamilyRelationship>> watchAsCaregiver(String uid) =>
      _rel.where('caregiverUid', isEqualTo: uid).snapshots().map((s) => s.docs.map(FamilyRelationship.fromDoc).toList());
  @override
  Stream<List<Invitation>> watchSent(String id) => _db.collection('invitations').where('patientId', isEqualTo: id).snapshots()
      .map((s) => s.docs.map(Invitation.fromDoc).where((i) => i.isPending).toList());
  @override
  Stream<List<Invitation>> watchReceived(String email) => _db.collection('invitations').where('email', isEqualTo: email.toLowerCase()).snapshots()
      .map((s) => s.docs.map(Invitation.fromDoc).where((i) => i.isPending).toList());

  @override
  Future<void> setPermission(FamilyRelationship r, String p, bool v) =>
      guard(() => _rel.doc(r.id).update({'permissions.$p': v, 'updatedAt': FieldValue.serverTimestamp()}), write: true);
  @override
  Future<void> revoke(FamilyRelationship r) =>
      guard(() => _rel.doc(r.id).update({'status': 'revoked', 'updatedAt': FieldValue.serverTimestamp()}), write: true);
  @override
  Future<void> leave(FamilyRelationship r) =>
      guard(() => _rel.doc(r.id).update({'status': 'left', 'updatedAt': FieldValue.serverTimestamp()}), write: true);
  @override
  Future<void> cancelInvitation(String id) =>
      guard(() => _db.collection('invitations').doc(id).update({'status': 'cancelled'}), write: true);

  @override
  Future<InviteResult> invite(String email) => guard(() async {
        final r = await _fn.httpsCallable('createInvitation').call({'email': email.trim().toLowerCase()});
        final d = Map<String, dynamic>.from(r.data as Map);
        return InviteResult(d['code'] as String, DateTime.fromMillisecondsSinceEpoch(d['expiresAt'] as int));
      });

  @override
  Future<void> accept({String? invitationId, String? code}) => guard(() async {
        await _fn.httpsCallable('acceptInvitation').call({'invitationId': invitationId, 'code': code});
      });
}
