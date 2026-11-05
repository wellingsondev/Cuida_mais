import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/common.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/consultation.dart';
import '../providers/consultation_providers.dart';

class ConsultationsScreen extends ConsumerStatefulWidget {
  const ConsultationsScreen({super.key});
  @override
  ConsumerState<ConsultationsScreen> createState() => _State();
}

class _State extends ConsumerState<ConsultationsScreen> {
  DateTime _selected = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider)!;
    final value = ref.watch(consultationsProvider(uid));
    return Scaffold(
      appBar: AppBar(title: const Text('Consultas e calendário')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/consultations/new', extra: _selected), icon: const Icon(Icons.add), label: const Text('Nova')),
      body: AsyncBody(
        value: value,
        onRetry: () => ref.invalidate(consultationsProvider(uid)),
        builder: (all) {
          final day = all.where((c) => dateOnly(c.dateTime) == _selected).toList();
          final upcoming = all.where((c) => c.status == 'scheduled' && c.dateTime.isAfter(DateTime.now())).take(10).toList();
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
            Card(child: CalendarDatePicker(initialDate: _selected, firstDate: DateTime(2020), lastDate: DateTime(2100), onDateChanged: (d) => setState(() => _selected = dateOnly(d)))),
            Text(fmtDateLong(_selected), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (day.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Nenhuma consulta neste dia.', style: TextStyle(color: Colors.black54))),
            for (final c in day) ConsultationTile(c, onTap: () => context.push('/consultations/${c.id}/edit')),
            const SizedBox(height: 16),
            Text('Próximas consultas', style: Theme.of(context).textTheme.titleMedium),
            if (upcoming.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Nada agendado.', style: TextStyle(color: Colors.black54))),
            for (final c in upcoming) ConsultationTile(c, onTap: () => context.push('/consultations/${c.id}/edit')),
          ]);
        },
      ),
    );
  }
}

class ConsultationTile extends StatelessWidget {
  final Consultation c;
  final VoidCallback? onTap;
  const ConsultationTile(this.c, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = c.status == 'done' ? AppColors.success : (c.status == 'cancelled' ? Colors.grey : AppColors.primary);
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(Icons.local_hospital, color: color)),
        title: Text(c.professional, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([if (c.specialty.isNotEmpty) c.specialty, fmtDateTime(c.dateTime), if (c.location.isNotEmpty) c.location].join('\n')),
        isThreeLine: true,
        trailing: c.pendingSync ? const Icon(Icons.cloud_upload_outlined, color: AppColors.warning) : StatusChip(Consultation.statusLabels[c.status] ?? '', color),
      ),
    );
  }
}

/// Lista somente leitura usada na visão do familiar.
class ConsultationsListView extends ConsumerWidget {
  final String patientId;
  const ConsultationsListView({super.key, required this.patientId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncBody(
        value: ref.watch(consultationsProvider(patientId)),
        builder: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.event_available, title: 'Nenhuma consulta')
            : ListView(padding: const EdgeInsets.all(16), children: [for (final c in list) ConsultationTile(c)]),
      );
}
