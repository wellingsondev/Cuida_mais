import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common.dart';
import '../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashState();
}

class _SplashState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    final session = await ref.read(authSessionProvider.future);
    if (!mounted || session != null) return; // logado: o router decide o destino
    final seen = (await SharedPreferences.getInstance()).getBool('onboarded') ?? false;
    if (mounted) context.go(seen ? '/login' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.favorite, size: 84, color: Colors.white),
            SizedBox(height: 12),
            Text('Cuida+', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends State<OnboardingScreen> {
  final _c = PageController();
  int _i = 0;
  static const _pages = [
    (Icons.medication, 'Organize seus medicamentos', 'Cadastre os remédios e horários que você já recebeu orientação para usar.'),
    (Icons.notifications_active, 'Receba lembretes', 'Avisos nos horários certos, mesmo com o aplicativo fechado.'),
    (Icons.family_restroom, 'Acompanhamento familiar', 'Você escolhe quem acompanha e o que cada pessoa pode ver. Pode revogar quando quiser.'),
  ];

  Future<void> _finish() async {
    await (await SharedPreferences.getInstance()).setBool('onboarded', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: PageView(
                controller: _c,
                onPageChanged: (i) => setState(() => _i = i),
                children: [
                  for (final p in _pages)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(p.$1, size: 110, color: AppColors.primary),
                        const SizedBox(height: 24),
                        Text(p.$2, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(p.$3, style: const TextStyle(fontSize: 17, color: Colors.black54), textAlign: TextAlign.center),
                      ]),
                    ),
                ],
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _pages.length; i++)
                Container(margin: const EdgeInsets.all(4), width: 10, height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i == _i ? AppColors.primary : Colors.black12)),
            ]),
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 12, 32, 0),
              child: Text('O Cuida+ não indica medicamentos nem doses. Siga sempre a orientação do seu profissional de saúde.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: () => _i == _pages.length - 1 ? _finish() : _c.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                child: Text(_i == _pages.length - 1 ? 'Começar' : 'Avançar'),
              ),
            ),
          ]),
        ),
      );
}

class _AuthScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _AuthScaffold({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent),
        body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: children)),
      );
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _pass = TextEditingController();
  bool _busy = false, _hide = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await runAction(context, () => ref.read(authRepositoryProvider).signIn(_email.text, _pass.text));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(title: 'Entrar', children: [
        const Icon(Icons.favorite, size: 64, color: AppColors.primary),
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)), validator: Validators.email),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pass, obscureText: _hide, autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: 'Senha', prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _hide = !_hide))),
              validator: (v) => Validators.required(v, 'Senha'),
              onFieldSubmitted: (_) => _submit(),
            ),
          ]),
        ),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.push('/forgot'), child: const Text('Esqueci minha senha'))),
        const SizedBox(height: 8),
        FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Entrar')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => context.push('/register'), child: const Text('Criar conta')),
      ]);
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController(), _pass = TextEditingController();
  String _role = 'patient';
  bool _accepted = false, _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aceite a Política de Privacidade para continuar.')));
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(context,
        () => ref.read(authRepositoryProvider).signUp(name: _name.text, email: _email.text, password: _pass.text, role: _role),
        success: 'Conta criada! Enviamos um e-mail de verificação.');
    if (mounted) {
      setState(() => _busy = false);
      if (ok && context.canPop()) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(title: 'Criar conta', children: [
        Form(
          key: _form,
          child: Column(children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'patient', label: Text('Sou paciente'), icon: Icon(Icons.person)),
                ButtonSegment(value: 'caregiver', label: Text('Sou familiar'), icon: Icon(Icons.family_restroom)),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome completo'), validator: Validators.name),
            const SizedBox(height: 16),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail'), validator: Validators.email),
            const SizedBox(height: 16),
            TextFormField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Senha', helperText: 'Mínimo de 8 caracteres, com letras e números'), validator: Validators.password),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero, value: _accepted, onChanged: (v) => setState(() => _accepted = v ?? false),
              title: const Text('Li e aceito a Política de Privacidade e o tratamento dos meus dados de saúde para a finalidade de lembretes e acompanhamento.', style: TextStyle(fontSize: 14)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('Criar conta')),
      ]);
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotState();
}

class _ForgotState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  Widget build(BuildContext context) => _AuthScaffold(title: 'Recuperar senha', children: [
        const Text('Informe seu e-mail. Se houver uma conta, enviaremos um link para redefinir a senha.'),
        const SizedBox(height: 16),
        Form(key: _form, child: TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail'), validator: Validators.email)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            final nav = GoRouter.of(context);
            final ok = await runAction(context, () => ref.read(authRepositoryProvider).sendPasswordReset(_email.text),
                success: 'Se o e-mail estiver cadastrado, você receberá o link em instantes.');
            if (ok && mounted) nav.pop();
          },
          child: const Text('Enviar link'),
        ),
      ]);
}

class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(authRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Verifique seu e-mail'), actions: [TextButton(onPressed: repo.signOut, child: const Text('Sair'))]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.mark_email_unread, size: 96, color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Enviamos um link de confirmação para ${repo.currentEmail ?? 'seu e-mail'}. Abra-o e depois toque em "Já verifiquei".', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => runAction(context, repo.reloadUser), child: const Text('Já verifiquei')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => runAction(context, repo.sendEmailVerification, success: 'E-mail reenviado.'), child: const Text('Reenviar e-mail')),
          ]),
        ),
      ),
    );
  }
}
