import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/presentation/providers/auth_providers.dart';
import '../features/authentication/presentation/screens/auth_screens.dart';
import '../features/consultations/presentation/screens/consultation_form_screen.dart';
import '../features/consultations/presentation/screens/consultations_screen.dart';
import '../features/family/presentation/screens/family_screen.dart';
import '../features/family/presentation/screens/caregiver_screens.dart';
import '../features/history/presentation/screens/history_screen.dart';
import '../features/home/presentation/screens/patient_home_screen.dart';
import '../features/medications/presentation/screens/medication_detail_screen.dart';
import '../features/medications/presentation/screens/medication_form_screen.dart';
import '../features/medications/presentation/screens/medications_screen.dart';
import '../features/profile/presentation/screens/profile_screens.dart';
import '../features/reminders/presentation/screens/notifications_screen.dart';

const _public = {'/splash', '/onboarding', '/login', '/register', '/forgot'};
const _patientPrefixes = ['/home', '/medications', '/consultations', '/history', '/family', '/profile', '/notifications'];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authSessionProvider, (_, __) => refresh.value++);
  ref.listen(profileProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String? redirect(BuildContext _, GoRouterState state) {
    final loc = state.matchedLocation;
    final session = ref.read(authSessionProvider);
    if (session.isLoading && !session.hasValue) return loc == '/splash' ? null : '/splash';
    final s = session.value;
    if (s == null) return _public.contains(loc) ? null : '/login';
    if (!s.emailVerified) return loc == '/verify' ? null : '/verify';
    final profile = ref.read(profileProvider);
    final role = profile.value?.role;
    if (role == null) return loc == '/splash' ? null : '/splash'; // aguardando perfil
    final home = role == 'patient' ? '/home' : '/caregiver';
    if (_public.contains(loc) || loc == '/verify') return home;
    if (loc == '/settings') return null;
    final isCaregiverArea = loc.startsWith('/caregiver') || loc.startsWith('/patient/');
    if (role == 'patient' && isCaregiverArea) return home;
    if (role == 'caregiver' && !isCaregiverArea) return home;
    if (role == 'patient' && !_patientPrefixes.any(loc.startsWith)) return home;
    return null;
  }

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/verify', builder: (_, __) => const VerifyEmailScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/patient/:id', builder: (_, s) => PatientViewScreen(patientId: s.pathParameters['id']!)),

      // ----- Paciente -----
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => NavShell(shell: shell, destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Hoje'),
          NavigationDestination(icon: Icon(Icons.medication_outlined), selectedIcon: Icon(Icons.medication), label: 'Remédios'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Consultas'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Família'),
        ]),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const PatientHomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/medications', builder: (_, __) => const MedicationsScreen(), routes: [
              GoRoute(path: 'new', builder: (_, __) => const MedicationFormScreen()),
              GoRoute(path: ':id', builder: (_, s) => MedicationDetailScreen(medicationId: s.pathParameters['id']!), routes: [
                GoRoute(path: 'edit', builder: (_, s) => MedicationFormScreen(medicationId: s.pathParameters['id'])),
              ]),
            ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/consultations', builder: (_, __) => const ConsultationsScreen(), routes: [
              GoRoute(path: 'new', builder: (_, s) => ConsultationFormScreen(initialDate: s.extra as DateTime?)),
              GoRoute(path: ':id/edit', builder: (_, s) => ConsultationFormScreen(consultationId: s.pathParameters['id'])),
            ]),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/history', builder: (_, __) => const PatientHistoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/family', builder: (_, __) => const FamilyScreen())]),
        ],
      ),

      // ----- Familiar / cuidador -----
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => NavShell(shell: shell, destinations: const [
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Pacientes'),
          NavigationDestination(icon: Icon(Icons.mail_outline), selectedIcon: Icon(Icons.mail), label: 'Convites'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Avisos'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ]),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/caregiver', builder: (_, __) => const CaregiverHomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/caregiver/invites', builder: (_, __) => const InvitesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/caregiver/notifications', builder: (_, __) => const NotificationsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/caregiver/profile', builder: (_, __) => const ProfileScreen())]),
        ],
      ),
    ],
  );
});

class NavShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  final List<NavigationDestination> destinations;
  const NavShell({super.key, required this.shell, required this.destinations});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: destinations,
        ),
      );
}
