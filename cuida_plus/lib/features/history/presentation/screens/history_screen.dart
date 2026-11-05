import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/common.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/med_log.dart';
import '../providers/history_providers.dart';

Color statusColor(DoseStatus s) => switch (s) {
      DoseStatus.confirmed => AppColors.success,
      DoseStatus.pending => AppColors.warning,
      DoseStatus.notDone => AppColors.danger,
      DoseStatus.postponed => AppColors.primary,
    };

class PatientHistoryScreen extends ConsumerWidget {
  const PatientHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Histórico')),
        body: HistoryListView(patientId: ref.watch(currentUidProvider)!),
      );
}

class HistoryListView extends ConsumerStatefulWidget {
  final String patientId;
  const HistoryListView({super.key, required this.patientId});
  @override
  ConsumerState<HistoryListView> createState() => _State();
}

class _State extends ConsumerState<HistoryListView> {
  DoseStatus? _filter;
  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUidProvider);
    return Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text('Os registros refletem apenas o que o usuário informou. Não comprovam o uso do medicamento.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(12),
        child: Row(children: [
          Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: const Text('Todos'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null))),
          for (final s in DoseStatus.values)
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(s.label.split(',').first), selected: _filter == s, onSelected: (_) => setState(() => _filter = s))),
        ]),
      ),
      Expanded(
        child: AsyncBody(
          value: ref.watch(logsProvider((patientId: widget.patientId, days: 90))),
          onRetry: () => ref.invalidate(logsProvider((patientId: widget.patientId, days: 90))),
          builder: (logs) {
            final list = logs.where((l) => _filter == null || l.status == _filter).toList();
            if (list.isEmpty) return const EmptyState(icon: Icons.history, title: 'Sem registros', subtitle: 'Os últimos 90 dias aparecem aqui.');
            return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              for (final l in list)
                Card(
                  child: ListTile(
                    title: Text(l.medicationName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      'Previsto: ${fmtDateTime(l.scheduledAt)}',
                      if (l.confirmedAt != null) 'Confirmado às ${fmtTime(l.confirmedAt!)}',
                      if (l.actorUid.isNotEmpty && l.actorUid != 'system') 'Registrado por: ${l.actorUid == me ? 'você' : l.actorName}',
                    ].join('\n')),
                    isThreeLine: true,
                    trailing: l.pendingSync ? const Icon(Icons.cloud_upload_outlined, color: AppColors.warning) : StatusChip(l.status.label.split(',').first, statusColor(l.status)),
                  ),
                ),
            ]);
          },
        ),
      ),
    ]);
  }
}
