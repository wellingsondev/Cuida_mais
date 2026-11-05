import '../entities/family.dart';

abstract class FamilyRepository {
  Stream<List<FamilyRelationship>> watchAsPatient(String patientId);
  Stream<List<FamilyRelationship>> watchAsCaregiver(String caregiverUid);
  Stream<List<Invitation>> watchSent(String patientId);
  Stream<List<Invitation>> watchReceived(String email);
  Future<void> setPermission(FamilyRelationship r, String permission, bool value);
  Future<void> revoke(FamilyRelationship r);
  Future<void> leave(FamilyRelationship r);
  Future<void> cancelInvitation(String id);
  Future<InviteResult> invite(String email);
  Future<void> accept({String? invitationId, String? code});
}
