import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/common.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/medication_providers.dart';

class MedicationDetailScreen extends ConsumerWidget {
  final String medicationId;
  const MedicationDetailScreen({super.key, required this.medicationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider)!;
    final meds = ref.watch(medicationsProvider(uid));
    final scheds = (ref.watch(schedulesProvider(uid)).value ?? []).where((s) => s.medicationId == medicationId).toList();
    final repo = ref.read(medicationRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do medicamento')),
      body: AsyncBody(
        value: meds,
        builder: (list) {
          final m = list.where((x) => x.id == medicationId).firstOrNull;
          if (m == null) return const EmptyState(icon: Icons.search_off, title: 'Medicamento não encontrado');
          Widget row(String k, String v) => ListTile(dense: true, title: Text(k, style: const TextStyle(color: Colors.black54)), subtitle: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontSize: 16, color: Colors.black87)));
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(child: Column(children: [
              ListTile(title: Text(m.name, style: Theme.of(context).textTheme.titleLarge), subtitle: Text(m.archived ? 'Arquivado' : (m.active ? 'Ativo' : 'Inativo'))),
              row('Dosagem (conforme prescrição)', m.dosage),
              row('Forma de apresentação', m.form),
              row('Início', fmtDate(m.startDate)),
              row('Término', m.endDate == null ? 'Sem data final' : fmtDate(m.endDate!)),
              row('Observações', m.notes),
            ])),
            Card(child: Column(children: [
              const ListTile(title: Text('Horários', style: TextStyle(fontWeight: FontWeight.w600))),
              Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, children: [for (final s in scheds) Chip(avatar: const Icon(Icons.schedule, size: 18), label: Text(s.label))]))),
              SwitchListTile(title: const Text('Medicamento ativo'), value: m.active, onChanged: m.archived ? null : (v) => runAction(context, () => repo.setActive(m, v))),
              SwitchListTile(title: const Text('Lembretes ligados'), value: m.remindersEnabled, onChanged: m.archived ? null : (v) => runAction(context, () => repo.setReminders(m, v))),
            ])),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: () => context.push('/medications/${m.id}/edit'), icon: const Icon(Icons.edit), label: const Text('Editar e alterar horários')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                if (await confirmDialog(context, title: 'Arquivar medicamento?', message: 'Ele deixará de gerar lembretes, mas o histórico será mantido.', confirm: 'Arquivar')) {
                  if (context.mounted && await runAction(context, () => repo.archive(m), success: 'Medicamento arquivado.') && context.mounted) context.pop();
                }
              },
              icon: const Icon(Icons.archive_outlined), label: const Text('Arquivar'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () async {
                if (await confirmDialog(context, title: 'Excluir definitivamente?', message: 'O medicamento e seus horários serão apagados. O histórico já registrado é mantido.', confirm: 'Excluir', danger: true)) {
                  if (context.mounted && await runAction(context, () => repo.delete(m), success: 'Medicamento excluído.') && context.mounted) context.pop();
                }
              },
              icon: const Icon(Icons.delete_outline), label: const Text('Excluir'),
            ),
          ]);
        },
      ),
    );
  }
}
