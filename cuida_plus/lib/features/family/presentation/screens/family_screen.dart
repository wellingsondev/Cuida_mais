import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common.dart';
import '../../../../models/permissions.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/family_providers.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final key = GlobalKey<FormState>();
    final email = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Convidar familiar'),
        content: Form(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('O familiar poderá acompanhar o que você autorizar. Você pode revogar o acesso quando quiser.', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextFormField(controller: c, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail do familiar'), validator: Validators.email),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: () { if (key.currentState!.validate()) Navigator.pop(d, c.text); }, child: const Text('Convidar')),
        ],
      ),
    );
    if (email == null || !context.mounted) return;
    String? code;
    DateTime? exp;
    final ok = await runAction(context, () async {
      final r = await ref.read(familyRepositoryProvider).invite(email);
      code = r.code; exp = r.expiresAt;
    });
    if (ok && code != null && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Convite criado'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Se $email já tem conta, ela foi avisada. Você também pode compartilhar este código (válido até ${fmtDate(exp!)}):'),
            const SizedBox(height: 12),
            SelectableText(code!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 2)),
          ]),
          actions: [
            TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: code!)); Navigator.pop(d); }, child: const Text('Copiar')),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Fechar')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider)!;
    final rels = ref.watch(patientRelationshipsProvider(uid));
    final invites = ref.watch(sentInvitationsProvider(uid)).value ?? [];
    final repo = ref.read(familyRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Acompanhamento familiar')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _invite(context, ref), icon: const Icon(Icons.person_add), label: const Text('Convidar')),
      body: AsyncBody(
        value: rels,
        onRetry: () => ref.invalidate(patientRelationshipsProvider(uid)),
        builder: (all) {
          final active = all.where((r) => r.isActive).toList();
          if (active.isEmpty && invites.isEmpty) {
            return const EmptyState(icon: Icons.family_restroom, title: 'Ninguém acompanha você ainda', subtitle: 'Convide um familiar ou cuidador. Você decide o que ele pode ver.');
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
            for (final r in active)
              Card(
                child: ExpansionTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(r.caregiverName.isEmpty ? r.caregiverEmail : r.caregiverName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(r.caregiverEmail),
                  children: [
                    for (final e in Permission.labels.entries)
                      SwitchListTile(title: Text(e.value), value: r.permissions[e.key] ?? false, onChanged: (v) => runAction(context, () => repo.setPermission(r, e.key, v))),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        icon: const Icon(Icons.block), label: const Text('Revogar acesso'),
                        onPressed: () async {
                          if (await confirmDialog(context, title: 'Revogar acesso?', message: 'Este familiar deixará de ver seus dados imediatamente.', confirm: 'Revogar', danger: true)) {
                            if (context.mounted) runAction(context, () => repo.revoke(r), success: 'Acesso revogado.');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            if (invites.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.only(top: 16, bottom: 4), child: Text('Convites pendentes', style: TextStyle(fontWeight: FontWeight.w600))),
              for (final i in invites)
                Card(child: ListTile(leading: const Icon(Icons.hourglass_top), title: Text(i.email), subtitle: Text('Expira em ${i.expiresAt == null ? '—' : fmtDate(i.expiresAt!)}'),
                    trailing: IconButton(tooltip: 'Cancelar convite', icon: const Icon(Icons.close), onPressed: () => runAction(context, () => repo.cancelInvitation(i.id))))),
            ],
          ]);
        },
      ),
    );
  }
}
