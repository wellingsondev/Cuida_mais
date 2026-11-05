import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/permissions.dart';

class FamilyRelationship {
  final String id, patientId, patientName, caregiverUid, caregiverName, caregiverEmail, status; // active | revoked | left
  final Map<String, bool> permissions;
  const FamilyRelationship({required this.id, required this.patientId, required this.patientName, required this.caregiverUid,
    required this.caregiverName, required this.caregiverEmail, required this.status, required this.permissions});

  bool can(String perm) => status == 'active' && permissions[perm] == true;
  bool get isActive => status == 'active';

  factory FamilyRelationship.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    final p = Map<String, dynamic>.from(m['permissions'] ?? {});
    return FamilyRelationship(
      id: d.id, patientId: m['patientId'], patientName: m['patientName'] ?? '', caregiverUid: m['caregiverUid'],
      caregiverName: m['caregiverName'] ?? '', caregiverEmail: m['caregiverEmail'] ?? '', status: m['status'] ?? 'active',
      permissions: {for (final k in Permission.labels.keys) k: p[k] == true},
    );
  }
}

class Invitation {
  final String id, patientId, patientName, email, status;
  final DateTime? expiresAt;
  const Invitation({required this.id, required this.patientId, required this.patientName, required this.email, required this.status, this.expiresAt});

  bool get isPending => status == 'pending' && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory Invitation.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Invitation(id: d.id, patientId: m['patientId'], patientName: m['patientName'] ?? '', email: m['email'] ?? '',
        status: m['status'] ?? 'pending', expiresAt: (m['expiresAt'] as Timestamp?)?.toDate());
  }
}

class InviteResult {
  final String code;
  final DateTime expiresAt;
  const InviteResult(this.code, this.expiresAt);
}
