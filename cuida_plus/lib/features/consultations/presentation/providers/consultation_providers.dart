import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_consultation_repository.dart';
import '../../domain/entities/consultation.dart';
import '../../domain/repositories/consultation_repository.dart';

final consultationRepositoryProvider =
    Provider<ConsultationRepository>((ref) => FirestoreConsultationRepository(ref.watch(firestoreProvider)));

final consultationsProvider = StreamProvider.family<List<Consultation>, String>(
    (ref, patientId) => ref.watch(consultationRepositoryProvider).watch(patientId));
