import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_service.dart';
import '../core/services/push_service.dart';
import '../features/authentication/presentation/providers/auth_providers.dart';
import 'app_theme.dart';
import 'routes.dart';

/// Efeitos colaterais ligados ao perfil: token FCM e consentimento de analytics.
final appBootstrapProvider = Provider<void>((ref) {
  ref.listen(profileProvider, (_, next) {
    final p = next.value;
    if (p == null) return;
    FirebaseService.applyAnalyticsConsent(p.analyticsConsent);
    PushService.registerForUser(p.uid);
  }, fireImmediately: true);
});

class CuidaApp extends ConsumerWidget {
  const CuidaApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appBootstrapProvider);
    return MaterialApp.router(
      title: 'Cuida+',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
