# Cuida+ — lembretes e cuidados (Flutter + Firebase)

App Flutter/Dart (Android primeiro; arquitetura pronta para iOS) com Riverpod, GoRouter, Firebase Auth/Firestore/FCM/App Check/Crashlytics/Analytics, notificações locais e Cloud Functions.

> ⚠️ **Estado desta entrega:** o código foi escrito sem acesso a Flutter/Firebase CLI, portanto **não foi compilado nem executado**. Espere ajustar pequenos detalhes no primeiro build (veja "Pontos de atenção"). Nada aqui foi validado em dispositivo.

## Passo a passo
1. `flutter create --org br.com.seudominio --platforms=android,ios cuida_plus` e **copie** `lib/`, `test/`, `pubspec.yaml`, `firebase.json`, `firestore.*`, `functions/`, `docs/` por cima (mantenha `android/` e `ios/` gerados).
2. Crie o projeto no Firebase Console. Ative: Authentication (e-mail/senha), Firestore (região `southamerica-east1`), Cloud Messaging, App Check (Play Integrity), Crashlytics, Analytics. Para Cloud Functions é necessário o plano Blaze.
3. `dart pub global activate flutterfire_cli && flutterfire configure` (gera o `firebase_options.dart` real e os arquivos de plataforma).
4. `flutter pub get` — as dependências estão como `any`; o pub escolhe versões estáveis compatíveis. Depois de compilar, **versione o `pubspec.lock`** ou fixe as versões. Se precisar: `flutter pub upgrade --major-versions`.
5. Aplique `android_setup/AndroidManifest_additions.xml` (permissões, receivers de boot, desugaring) e configure o plugin do Crashlytics conforme a documentação do FlutterFire.
6. `firebase deploy --only firestore:rules,firestore:indexes` e `cd functions && npm i && cd .. && firebase deploy --only functions`.
7. App Check: em debug, registre o *debug token* mostrado no logcat no console do Firebase; ative a imposição (enforcement) quando estável.
8. `flutter run`.

## Testes
- `flutter test` — validadores, geração de doses (regras de negócio), IDs de notificação, widgets.
- Regras do Firestore (Emulator Suite): `cd test/rules && npm i && npm test` (usuário acessando dados de outro, familiar sem vínculo, vínculo revogado, medicamento inválido, não verificado, histórico imutável).
- **Não incluídos:** testes de integração do app (`integration_test`) com emulador de Auth/Firestore/Functions, e testes das Cloud Functions. Recomendo escrevê-los após o primeiro build; veja `docs/` para o fluxo.

## Como cada requisito foi atendido
- **Permissões no backend:** `firestore.rules` (vínculo ativo + permissão específica) e verificações nas funções. Esconder abas na UI é só conveniência.
- **FCM de verdade:** `functions/index.js` — gatilhos em logs/medicamentos, `checkMissedDoses` (a cada 5 min) e `checkUpcomingConsultations`; idempotência via `notification_events` com `create()`; sem credenciais no app.
- **Lembretes locais:** `notification_service.dart` — IDs estáveis (sem duplicatas), recria agendamentos a cada alteração, respeita início/término, fuso do aparelho, reinício via receiver de boot.
- **Offline:** cache do Firestore + escritas em fila; indicador de "aguardando sincronização". Não há camada local separada (SQLite/Drift); se precisar de operação offline mais pesada, planeje-a à parte.
- **LGPD:** consentimento no cadastro e para Analytics (desligado por padrão), exportação e exclusão de dados, revogação por permissão, `docs/POLITICA_PRIVACIDADE.md` (modelo para revisão jurídica).

## Pontos de atenção (APIs mudam entre versões)
- `flutter_local_notifications`: `initialize`/`zonedSchedule` mudaram de assinatura entre versões maiores; ajuste conforme o erro do compilador.
- `firebase_app_check`: parâmetro `androidProvider` pode estar depreciado/substituído por `providerAndroid` nas versões novas.
- `flutter_timezone`: o retorno mudou (String → objeto); o código trata os dois casos.
- Riverpod 3: `ref.listen`/providers usados são os básicos; se usar a 2.x também funciona.
- Convites: o código é mostrado ao paciente para compartilhar; **não há envio de e-mail** (para isso integre um provedor ou a extensão *Trigger Email*). Se o convidado já tem conta, recebe notificação.
- `checkMissedDoses` varre todos os horários ativos a cada 5 min — suficiente para MVP; para escala, particione por fuso/horário.
- Lembretes locais com data de término são agendados por dia (até 60); o app recalcula ao abrir. Sem término, usa repetição diária nativa.
- Teste em aparelhos reais com economia de bateria (Xiaomi, Samsung etc.): fabricantes podem atrasar alarmes; oriente o usuário a liberar "sem restrições".
- O app não substitui orientação médica e não comprova ingestão (avisos já estão na UI).
