import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/repositories/firebase_family_repository.dart';
import '../../domain/entities/family.dart';
import '../../domain/repositories/family_repository.dart';

final familyRepositoryProvider =
    Provider<FamilyRepository>((ref) => FirebaseFamilyRepository(ref.watch(firestoreProvider), ref.watch(functionsProvider)));

final patientRelationshipsProvider = StreamProvider.family<List<FamilyRelationship>, String>(
    (ref, id) => ref.watch(familyRepositoryProvider).watchAsPatient(id));
final caregiverRelationshipsProvider = StreamProvider.family<List<FamilyRelationship>, String>(
    (ref, uid) => ref.watch(familyRepositoryProvider).watchAsCaregiver(uid));
final sentInvitationsProvider =
    StreamProvider.family<List<Invitation>, String>((ref, id) => ref.watch(familyRepositoryProvider).watchSent(id));
final receivedInvitationsProvider =
    StreamProvider.family<List<Invitation>, String>((ref, email) => ref.watch(familyRepositoryProvider).watchReceived(email));
