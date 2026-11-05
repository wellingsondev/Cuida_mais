import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/push_service.dart';
import '../../../../core/widgets/common.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref, String uid) async {
    if (!await confirmDialog(context, title: 'Sair da conta?', message: 'Os lembretes deste aparelho serão desativados até você entrar novamente.', confirm: 'Sair')) return;
    await PushService.unregister(uid);
    await NotificationService.instance.cancelAll();
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final pass = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Excluir conta'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Todos os seus dados (medicamentos, histórico, consultas e vínculos) serão apagados permanentemente. Por segurança, confirme sua senha.'),
          const SizedBox(height: 12),
          TextField(controller: c, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(96, 44)), onPressed: () => Navigator.pop(d, c.text), child: const Text('Excluir')),
        ],
      ),
    );
    if (pass == null || pass.isEmpty || !context.mounted) return;
    final uid = ref.read(currentUidProvider);
    final ok = await runAction(context, () async {
      if (uid != null) await PushService.unregister(uid);
      await ref.read(authRepositoryProvider).deleteAccount(pass);
      await NotificationService.instance.cancelAll();
    }, success: 'Conta excluída.');
    if (ok && context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).value;
    final verified = ref.watch(authSessionProvider).value?.emailVerified ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: p == null
          ? const LoadingView()
          : ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: Column(children: [
                ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(p.email)),
                ListTile(leading: const Icon(Icons.badge_outlined), title: Text(p.isPatient ? 'Paciente' : 'Familiar / cuidador')),
                ListTile(leading: Icon(verified ? Icons.verified : Icons.warning_amber, color: verified ? AppColors.success : AppColors.warning), title: Text(verified ? 'E-mail verificado' : 'E-mail não verificado')),
              ])),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () => context.push('/settings'), icon: const Icon(Icons.privacy_tip_outlined), label: const Text('Configurações e privacidade')),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () => _logout(context, ref, p.uid), icon: const Icon(Icons.logout), label: const Text('Sair')),
              const SizedBox(height: 8),
              OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger), onPressed: () => _delete(context, ref), icon: const Icon(Icons.delete_forever), label: const Text('Excluir minha conta')),
            ]),
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> {
  bool? _remote;

  @override
  void initState() {
    super.initState();
    final uid = ref.read(currentUidProvider);
    if (uid != null) {
      ref.read(notificationRepositoryProvider).remoteEnabled(uid).then((v) { if (mounted) setState(() => _remote = v); }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider).value;
    final uid = ref.watch(currentUidProvider);
    if (p == null || uid == null) return Scaffold(appBar: AppBar(title: const Text('Configurações')), body: const LoadingView());
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações e privacidade')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Notificações', style: TextStyle(fontWeight: FontWeight.w700)),
        ListTile(leading: const Icon(Icons.notifications_active_outlined), title: const Text('Permitir notificações neste aparelho'), onTap: () async {
          final ok = await NotificationService.instance.requestPermission();
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Notificações permitidas.' : 'Permissão negada. Ative nas configurações do sistema.')));
        }),
        ListTile(leading: const Icon(Icons.alarm_on), title: const Text('Permitir alarmes exatos'), subtitle: const Text('Lembretes no minuto exato (Android 12+)'), onTap: NotificationService.instance.requestExactAlarms),
        SwitchListTile(
          title: const Text('Receber avisos de acompanhamento'), subtitle: const Text('Avisos enviados por pacientes/familiares vinculados'),
          value: _remote ?? true, onChanged: _remote == null ? null : (v) async { setState(() => _remote = v); await runAction(context, () => ref.read(notificationRepositoryProvider).setRemoteEnabled(uid, v)); },
        ),
        const Divider(),
        const Text('Privacidade', style: TextStyle(fontWeight: FontWeight.w700)),
        SwitchListTile(
          title: const Text('Ajudar a melhorar o app (Analytics)'), subtitle: const Text('Dados de uso anônimos. Desligado por padrão.'),
          value: p.analyticsConsent,
          onChanged: (v) async { await runAction(context, () => ref.read(authRepositoryProvider).setAnalyticsConsent(uid, v)); await FirebaseService.applyAnalyticsConsent(v); },
        ),
        ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Política de Privacidade'), onTap: () => showDialog<void>(context: context, builder: (d) => AlertDialog(
          title: const Text('Política de Privacidade'),
          content: const SingleChildScrollView(child: Text(_policy)),
          actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Fechar'))],
        ))),
        ListTile(leading: const Icon(Icons.download_outlined), title: const Text('Exportar meus dados'), subtitle: const Text('Cópia dos seus dados em formato JSON (direito de acesso — LGPD)'), onTap: () async {
          String? json;
          final ok = await runAction(context, () => guard(() async {
                final r = await ref.read(functionsProvider).httpsCallable('exportMyData').call();
                json = const JsonEncoder.withIndent('  ').convert(r.data);
              }));
          if (ok && json != null && context.mounted) {
            showDialog<void>(context: context, builder: (d) => AlertDialog(title: const Text('Seus dados'), content: SingleChildScrollView(child: SelectableText(json!, style: const TextStyle(fontSize: 11))), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Fechar'))]));
          }
        }),
      ]),
    );
  }
}

const _policy = '''Resumo (modelo — revise com assessoria jurídica antes de publicar; texto completo em docs/POLITICA_PRIVACIDADE.md).

• Finalidade: lembretes de medicamentos e consultas e acompanhamento por pessoas que você autorizar.
• Dados tratados: nome, e-mail, medicamentos, horários, consultas e registros que você informar (dados de saúde — dados pessoais sensíveis).
• Compartilhamento: somente com familiares/cuidadores que você convidar, conforme as permissões que você definir. Você pode revogar a qualquer momento.
• Armazenamento: Google Firebase. Analytics só é ativado com o seu consentimento.
• Direitos (LGPD): acesso, correção, exportação, eliminação (Excluir minha conta) e revogação de consentimento.
• O Cuida+ não indica medicamentos nem doses e não comprova o uso: registra apenas o que você informou.''';
