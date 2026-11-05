import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_medication_repository.dart';
import '../../domain/entities/medication.dart';
import '../../domain/repositories/medication_repository.dart';

final medicationRepositoryProvider =
    Provider<MedicationRepository>((ref) => FirestoreMedicationRepository(ref.watch(firestoreProvider)));

final medicationsProvider = StreamProvider.family<List<Medication>, String>(
    (ref, patientId) => ref.watch(medicationRepositoryProvider).watchMedications(patientId));

final schedulesProvider = StreamProvider.family<List<MedSchedule>, String>(
    (ref, patientId) => ref.watch(medicationRepositoryProvider).watchSchedules(patientId));
