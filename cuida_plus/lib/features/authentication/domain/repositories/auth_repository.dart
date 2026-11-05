import '../entities/user_profile.dart';

abstract class AuthRepository {
  Stream<AuthSession?> sessionChanges();
  Stream<UserProfile?> watchProfile(String uid);
  String? get currentEmail;
  Future<void> signUp({required String name, required String email, required String password, required String role});
  Future<void> signIn(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> sendEmailVerification();
  Future<void> reloadUser();
  Future<void> signOut();
  Future<void> setAnalyticsConsent(String uid, bool granted);
  Future<void> deleteAccount(String password);
}
