import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/widgets/common.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/medication_providers.dart';

class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Meus medicamentos')),
      body: MedicationsListView(patientId: uid, onTap: (id) => context.push('/medications/$id')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/medications/new'), icon: const Icon(Icons.add), label: const Text('Novo')),
    );
  }
}

/// Lista reutilizada pelo paciente e pelo familiar (somente leitura quando [onTap] é nulo).
class MedicationsListView extends ConsumerWidget {
  final String patientId;
  final void Function(String id)? onTap;
  const MedicationsListView({super.key, required this.patientId, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(medicationsProvider(patientId));
    final scheds = ref.watch(schedulesProvider(patientId)).value ?? [];
    return AsyncBody(
      value: meds,
      onRetry: () => ref.invalidate(medicationsProvider(patientId)),
      builder: (list) {
        final visible = list.where((m) => !m.archived).toList();
        if (visible.isEmpty) {
          return const EmptyState(icon: Icons.medication_outlined, title: 'Nenhum medicamento cadastrado', subtitle: 'Cadastre os medicamentos conforme a orientação do seu profissional de saúde.');
        }
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
          for (final m in visible)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                onTap: onTap == null ? null : () => onTap!(m.id),
                leading: CircleAvatar(backgroundColor: (m.active ? AppColors.primary : Colors.grey).withValues(alpha: 0.12), child: Icon(Icons.medication, color: m.active ? AppColors.primary : Colors.grey)),
                title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text([m.dosage, if (m.form.isNotEmpty) m.form].join(' · ')),
                    for (final s in scheds.where((s) => s.medicationId == m.id)) Chip(label: Text(s.label), visualDensity: VisualDensity.compact),
                  ]),
                ),
                trailing: m.pendingSync
                    ? const Tooltip(message: 'Aguardando sincronização', child: Icon(Icons.cloud_upload_outlined, color: AppColors.warning))
                    : (m.active ? null : const StatusChip('Inativo', Colors.grey)),
              ),
            ),
        ]);
      },
    );
  }
}
