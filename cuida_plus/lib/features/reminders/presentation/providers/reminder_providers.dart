import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_service.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../consultations/presentation/providers/consultation_providers.dart';
import '../../../medications/presentation/providers/medication_providers.dart';
import '../../data/repositories/firestore_notification_repository.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => FirestoreNotificationRepository(ref.watch(firestoreProvider)));

final inboxProvider = StreamProvider.family<List<AppNotification>, String>(
    (ref, uid) => ref.watch(notificationRepositoryProvider).watch(uid));

/// Mantém os lembretes locais sincronizados com medicamentos, horários e consultas do paciente.
/// Qualquer alteração (horário, ativo/inativo, datas) refaz os agendamentos sem duplicar.
final reminderSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return;
  final meds = ref.watch(medicationsProvider(uid)).value;
  final scheds = ref.watch(schedulesProvider(uid)).value;
  final cons = ref.watch(consultationsProvider(uid)).value;
  if (meds == null || scheds == null || cons == null) return;
  NotificationService.instance.syncAll(meds: meds, schedules: scheds, consultations: cons);
});
