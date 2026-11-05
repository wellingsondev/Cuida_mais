import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid, name, email, role; // role: 'patient' | 'caregiver'
  final bool analyticsConsent;
  final DateTime? createdAt;
  const UserProfile({required this.uid, required this.name, required this.email, required this.role, this.analyticsConsent = false, this.createdAt});

  bool get isPatient => role == 'patient';
  String get firstName => name.trim().split(' ').first;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) => UserProfile(
        uid: uid,
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        role: m['role'] ?? 'patient',
        analyticsConsent: m['analyticsConsent'] == true,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );
}

class AuthSession {
  final String uid;
  final bool emailVerified;
  const AuthSession(this.uid, this.emailVerified);
  @override
  bool operator ==(Object other) => other is AuthSession && other.uid == uid && other.emailVerified == emailVerified;
  @override
  int get hashCode => Object.hash(uid, emailVerified);
}
