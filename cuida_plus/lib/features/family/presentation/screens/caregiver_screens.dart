import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/common.dart';
import '../../../../models/permissions.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../consultations/presentation/screens/consultations_screen.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../../medications/presentation/screens/medications_screen.dart';
import '../providers/family_providers.dart';

class CaregiverHomeScreen extends ConsumerWidget {
  const CaregiverHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider)!;
    final name = ref.watch(profileProvider).value?.firstName ?? '';
    return Scaffold(
      appBar: AppBar(title: Text('Olá, $name'), actions: [IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings'))]),
      body: AsyncBody(
        value: ref.watch(caregiverRelationshipsProvider(uid)),
        onRetry: () => ref.invalidate(caregiverRelationshipsProvider(uid)),
        builder: (all) {
          final active = all.where((r) => r.isActive).toList();
          if (active.isEmpty) {
            return EmptyState(icon: Icons.people_outline, title: 'Você ainda não acompanha ninguém', subtitle: 'Peça um convite ao paciente e aceite na aba "Convites".',
                action: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(160, 48)), onPressed: () => context.go('/caregiver/invites'), child: const Text('Ver convites')));
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final r in active)
              Card(child: ListTile(contentPadding: const EdgeInsets.all(16), leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(r.patientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                  subtitle: const Text('Toque para acompanhar'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/patient/${r.patientId}'))),
          ]);
        },
      ),
    );
  }
}

/// Visão do familiar: abas exibidas conforme as permissões (o backend também as exige).
class PatientViewScreen extends ConsumerWidget {
  final String patientId;
  const PatientViewScreen({super.key, required this.patientId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider)!;
    final rel = ref.watch(caregiverRelationshipsProvider(uid)).value?.where((r) => r.patientId == patientId && r.isActive).firstOrNull;
    if (rel == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.lock_outline, title: 'Acesso indisponível', subtitle: 'O vínculo foi encerrado ou não existe.'));

    final tabs = <(String, Widget)>[
      if (rel.can(Permission.viewMedications)) ('Remédios', MedicationsListView(patientId: patientId)),
      if (rel.can(Permission.viewHistory)) ('Histórico', HistoryListView(patientId: patientId)),
      if (rel.can(Permission.viewConsultations)) ('Consultas', ConsultationsListView(patientId: patientId)),
    ];
    return DefaultTabController(
      length: tabs.isEmpty ? 1 : tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(rel.patientName),
          actions: [
            PopupMenuButton<String>(
              onSelected: (_) async {
                if (await confirmDialog(context, title: 'Deixar de acompanhar?', message: 'Você perderá o acesso aos dados de ${rel.patientName}.', confirm: 'Deixar de acompanhar', danger: true)) {
                  if (context.mounted && await runAction(context, () => ref.read(familyRepositoryProvider).leave(rel)) && context.mounted) context.go('/caregiver');
                }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'leave', child: Text('Deixar de acompanhar'))],
            ),
          ],
          bottom: tabs.isEmpty ? null : TabBar(tabs: [for (final t in tabs) Tab(text: t.$1)]),
        ),
        body: tabs.isEmpty
            ? const EmptyState(icon: Icons.visibility_off, title: 'Nenhuma permissão concedida', subtitle: 'O paciente ainda não autorizou a visualização de dados.')
            : TabBarView(children: [for (final t in tabs) t.$2]),
      ),
    );
  }
}

class InvitesScreen extends ConsumerStatefulWidget {
  const InvitesScreen({super.key});
  @override
  ConsumerState<InvitesScreen> createState() => _InvitesState();
}

class _InvitesState extends ConsumerState<InvitesScreen> {
  final _code = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final email = ref.read(authRepositoryProvider).currentEmail ?? '';
    final repo = ref.read(familyRepositoryProvider);
    final invites = ref.watch(receivedInvitationsProvider(email));
    return Scaffold(
      appBar: AppBar(title: const Text('Convites')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Convites recebidos', style: Theme.of(context).textTheme.titleMedium),
        AsyncBody(
          value: invites,
          builder: (list) => list.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Text('Nenhum convite pendente para o seu e-mail.', style: TextStyle(color: Colors.black54)))
              : Column(children: [
                  for (final i in list)
                    Card(child: ListTile(title: Text(i.patientName), subtitle: Text('Expira em ${i.expiresAt == null ? '—' : fmtDate(i.expiresAt!)}'),
                        trailing: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: () => runAction(context, () => repo.accept(invitationId: i.id), success: 'Convite aceito!'), child: const Text('Aceitar')))),
                ]),
        ),
        const SizedBox(height: 24),
        Text('Tenho um código', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Código do convite')),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final code = _code.text.trim();
            if (code.isEmpty) return;
            if (await runAction(context, () => repo.accept(code: code), success: 'Convite aceito!')) _code.clear();
          },
          child: const Text('Aceitar com código'),
        ),
      ]),
    );
  }
}
