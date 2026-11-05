import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/common.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../consultations/presentation/providers/consultation_providers.dart';
import '../../../history/domain/entities/med_log.dart';
import '../../../history/presentation/providers/history_providers.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../../medications/domain/usecases/build_daily_doses.dart';
import '../../../medications/presentation/providers/medication_providers.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';

class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider)!;
    ref.watch(reminderSyncProvider); // mantém lembretes locais atualizados
    final profile = ref.watch(profileProvider).value;
    final meds = ref.watch(medicationsProvider(uid));
    final scheds = ref.watch(schedulesProvider(uid));
    final logs = ref.watch(logsProvider((patientId: uid, days: 1)));
    final cons = ref.watch(consultationsProvider(uid)).value ?? [];

    final now = DateTime.now();
    final nextConsult = cons.where((c) => c.status == 'scheduled' && c.dateTime.isAfter(now)).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${profile?.firstName ?? ''}'),
        actions: [
          IconButton(tooltip: 'Notificações', icon: const Icon(Icons.notifications_outlined), onPressed: () => context.push('/notifications')),
          IconButton(tooltip: 'Perfil', icon: const Icon(Icons.account_circle_outlined), onPressed: () => context.push('/profile')),
          IconButton(tooltip: 'Configurações', icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
        ],
      ),
      body: Builder(builder: (_) {
        final error = [meds, scheds, logs].where((v) => v.hasError && !v.hasValue).firstOrNull;
        if (error != null) return ErrorView(message: friendlyErrorOf(error.error!), onRetry: () { ref.invalidate(medicationsProvider(uid)); ref.invalidate(schedulesProvider(uid)); });
        if (!meds.hasValue || !scheds.hasValue || !logs.hasValue) return const LoadingView();
        final doses = buildDailyDoses(day: now, meds: meds.value!, schedules: scheds.value!, logs: logs.value!);
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text(fmtDateLong(now), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (nextConsult != null)
            Card(color: AppColors.primary.withValues(alpha: 0.06), child: ListTile(leading: const Icon(Icons.event, color: AppColors.primary), title: Text('Próxima consulta: ${nextConsult.professional}'), subtitle: Text(fmtDateTime(nextConsult.dateTime)))),
          const SizedBox(height: 8),
          Text('Medicamentos de hoje', style: Theme.of(context).textTheme.titleLarge),
          if (doses.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: EmptyState(icon: Icons.check_circle_outline, title: 'Nada programado para hoje', subtitle: 'Cadastre medicamentos na aba "Remédios".'))
          else
            for (final d in doses) DoseCard(dose: d),
          const Padding(padding: EdgeInsets.only(top: 16), child: Text('O Cuida+ registra somente o que você informa e não substitui a orientação de profissionais de saúde.', style: TextStyle(fontSize: 12, color: Colors.black54))),
        ]);
      }),
    );
  }
}

String friendlyErrorOf(Object e) => e is Exception || e is Error ? 'Não foi possível carregar seus dados. Verifique a conexão.' : '$e';

class DoseCard extends ConsumerWidget {
  final Dose dose;
  const DoseCard({super.key, required this.dose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = dose.status;
    final overdue = dose.isOverdue(DateTime.now());
    final profile = ref.watch(profileProvider).value;
    final repo = ref.read(historyRepositoryProvider);

    Future<void> register(DoseStatus s, {String? ok}) => runAction(context, () => repo.registerDose(dose: dose, status: s, actorUid: profile!.uid, actorName: profile.name), success: ok).then((success) {
          if (success && s == DoseStatus.postponed) NotificationService.instance.snooze(dose.logId, dose.medication.name);
        });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(dose.schedule.label, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (dose.log?.pendingSync == true) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.cloud_upload_outlined, color: AppColors.warning, size: 20)),
            StatusChip(overdue ? 'Atrasado' : status.label.split(',').first, overdue ? AppColors.danger : statusColor(status)),
          ]),
          const SizedBox(height: 6),
          Text(dose.medication.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          Text([dose.medication.dosage, if (dose.medication.form.isNotEmpty) dose.medication.form].join(' · '), style: const TextStyle(color: Colors.black54)),
          if (status != DoseStatus.confirmed) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 2, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: AppColors.success), onPressed: () => register(DoseStatus.confirmed, ok: 'Registro confirmado.'), icon: const Icon(Icons.check), label: const Text('Confirmar'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => register(DoseStatus.postponed, ok: 'Adiado por 15 minutos.'), child: const Text('Adiar'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => register(DoseStatus.notDone), child: const Text('Não fiz'))),
            ]),
          ] else if (dose.log?.confirmedAt != null)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('Confirmado às ${fmtTime(dose.log!.confirmedAt!)}', style: const TextStyle(color: AppColors.success))),
        ]),
      ),
    );
  }
}
