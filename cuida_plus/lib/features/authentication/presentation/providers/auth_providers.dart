import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
final functionsProvider = Provider<FirebaseFunctions>((_) => FirebaseFunctions.instanceFor(region: 'southamerica-east1'));

final authRepositoryProvider = Provider<AuthRepository>(
    (ref) => FirebaseAuthRepository(FirebaseAuth.instance, ref.watch(firestoreProvider), ref.watch(functionsProvider)));

final authSessionProvider = StreamProvider<AuthSession?>((ref) => ref.watch(authRepositoryProvider).sessionChanges());

final currentUidProvider = Provider<String?>((ref) => ref.watch(authSessionProvider).value?.uid);

final profileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(uid);
});
