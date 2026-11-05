import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._db, this._fn);
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  Stream<AuthSession?> sessionChanges() =>
      _auth.userChanges().map((u) => u == null ? null : AuthSession(u.uid, u.emailVerified));

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((s) => s.exists ? UserProfile.fromMap(s.id, s.data()!) : null);

  @override
  Future<void> signUp({required String name, required String email, required String password, required String role}) =>
      guard(() async {
        final mail = email.trim().toLowerCase();
        final cred = await _auth.createUserWithEmailAndPassword(email: mail, password: password); // senha nunca vai ao Firestore
        final user = cred.user!;
        try {
          await user.updateDisplayName(name.trim());
          final batch = _db.batch();
          batch.set(_db.collection('users').doc(user.uid), {
            'name': name.trim(), 'email': mail, 'role': role,
            'analyticsConsent': false, 'termsAcceptedAt': FieldValue.serverTimestamp(), 'createdAt': FieldValue.serverTimestamp(),
          });
          if (role == 'patient') {
            batch.set(_db.collection('patients').doc(user.uid),
                {'ownerUid': user.uid, 'name': name.trim(), 'createdAt': FieldValue.serverTimestamp()});
          }
          await batch.commit();
          await user.sendEmailVerification();
        } catch (e) {
          await user.delete(); // evita conta Auth órfã sem perfil
          rethrow;
        }
      });

  @override
  Future<void> signIn(String email, String password) =>
      guard(() => _auth.signInWithEmailAndPassword(email: email.trim().toLowerCase(), password: password));

  @override
  Future<void> sendPasswordReset(String email) => guard(() async {
        try {
          await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
        } on FirebaseAuthException catch (e) {
          if (e.code != 'user-not-found') rethrow; // não revela se o e-mail existe
        }
      });

  @override
  Future<void> sendEmailVerification() => guard(() async => _auth.currentUser?.sendEmailVerification());

  @override
  Future<void> reloadUser() => guard(() async {
        final u = _auth.currentUser;
        if (u == null) return;
        await u.reload();
        await _auth.currentUser?.getIdToken(true); // atualiza a claim email_verified usada nas regras
      });

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> setAnalyticsConsent(String uid, bool granted) =>
      guard(() => _db.collection('users').doc(uid).update({'analyticsConsent': granted}), write: true);

  @override
  Future<void> deleteAccount(String password) => guard(() async {
        final user = _auth.currentUser!;
        await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
        await _fn.httpsCallable('deleteMyData').call(); // apaga dados no backend
        await user.delete();
      });
}
