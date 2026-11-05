// Teste de integração contra o Firebase Emulator Suite (Auth + Firestore).
// 1) firebase emulators:start --only auth,firestore --project demo-cuida
// 2) flutter test integration_test/permissions_flow_test.dart   (emulador Android; host 10.0.2.2)
// Pré-requisito: o app deve ter sido configurado com `flutterfire configure`
// (ou use um FirebaseOptions fictício com projectId 'demo-cuida').
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cuida_plus/features/authentication/data/repositories/firebase_auth_repository.dart';
import 'package:cuida_plus/features/medications/data/repositories/firestore_medication_repository.dart';
import 'package:cuida_plus/features/medications/domain/entities/medication.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const host = '10.0.2.2';

/// Confirma o e-mail pelo link gerado no emulador (equivale a clicar no e-mail).
Future<void> verifyEmailOnEmulator(String email) async {
  final c = HttpClient();
  final req = await c.getUrl(Uri.parse('http://$host:9099/emulator/v1/projects/demo-cuida/oobCodes'));
  final body = jsonDecode(await (await req.close()).transform(utf8.decoder).join());
  final codes = (body['oobCodes'] as List).where((o) => o['email'] == email && o['requestType'] == 'VERIFY_EMAIL').toList();
  final link = (codes.last['oobLink'] as String).replaceFirst('localhost', host).replaceFirst('127.0.0.1', host);
  await (await c.getUrl(Uri.parse(link))).close().then((r) => r.drain());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirebaseFirestore db;
  late FirebaseAuthRepository authRepo;

  setUpAll(() async {
    await Firebase.initializeApp(options: const FirebaseOptions(apiKey: 'fake', appId: '1:1:android:1', messagingSenderId: '1', projectId: 'demo-cuida'));
    auth = FirebaseAuth.instance;
    db = FirebaseFirestore.instance;
    await auth.useAuthEmulator(host, 9099);
    db.useFirestoreEmulator(host, 8080);
    db.settings = const Settings(persistenceEnabled: false);
    authRepo = FirebaseAuthRepository(auth, db, FirebaseFunctions.instance);
  });

  Future<String> signUpVerified(String name, String role) async {
    final email = '${name.toLowerCase()}${DateTime.now().microsecondsSinceEpoch}@teste.com';
    await authRepo.signUp(name: name, email: email, password: 'senha1234', role: role);
    await verifyEmailOnEmulator(email);
    await authRepo.reloadUser(); // renova o token com email_verified = true
    return auth.currentUser!.uid;
  }

  testWidgets('paciente cadastra medicamento; outro usuário não consegue ler', (t) async {
    final patientUid = await signUpVerified('Paciente', 'patient');
    final repo = FirestoreMedicationRepository(db);
    final id = await repo.save(
      Medication(patientId: patientUid, name: 'Medicamento A', dosage: 'Conforme prescrição', startDate: DateTime.now()),
      [(hour: 8, minute: 0), (hour: 14, minute: 0), (hour: 20, minute: 0)],
      'America/Sao_Paulo',
    );
    final meds = await repo.watchMedications(patientUid).first;
    final scheds = await repo.watchSchedules(patientUid).first;
    expect(meds.single.id, id);
    expect(scheds, hasLength(3));

    // Salvar de novo com o mesmo horário não duplica (ID determinístico).
    await repo.save(meds.single, [(hour: 8, minute: 0), (hour: 14, minute: 0)], 'America/Sao_Paulo');
    expect(await repo.watchSchedules(patientUid).first, hasLength(2));

    // Outro usuário (sem convite) tenta ler os dados do paciente.
    await authRepo.signOut();
    await signUpVerified('Intruso', 'caregiver');
    expect(
      () => db.collection('medications').where('patientId', isEqualTo: patientUid).get(),
      throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
    );
  });

  testWidgets('medicamento inválido é rejeitado pelo backend', (t) async {
    final uid = await signUpVerified('Valida', 'patient');
    expect(
      () => db.collection('medications').add({'patientId': uid, 'name': '', 'dosage': 'x'}),
      throwsA(isA<FirebaseException>()),
    );
  });
}
