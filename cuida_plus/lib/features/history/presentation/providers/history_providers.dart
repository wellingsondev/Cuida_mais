import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_history_repository.dart';
import '../../domain/entities/med_log.dart';
import '../../domain/repositories/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => FirestoreHistoryRepository(ref.watch(firestoreProvider)));

/// [days]: janela retroativa (1 = hoje e ontem; 90 = histórico).
final logsProvider = StreamProvider.family<List<MedLog>, ({String patientId, int days})>((ref, k) =>
    ref.watch(historyRepositoryProvider).watchLogs(k.patientId, since: dateOnly(DateTime.now()).subtract(Duration(days: k.days))));
