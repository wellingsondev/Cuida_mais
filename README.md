# Cuida+

Aplicativo mobile (Flutter/Dart) para organizar **medicamentos, horários, consultas e cuidados pessoais**, com acompanhamento opcional por **familiares ou cuidadores**. Backend em Firebase (Authentication, Cloud Firestore, Cloud Messaging, App Check, Crashlytics, Analytics e Cloud Functions).

> **Aviso importante:** o Cuida+ **não indica medicamentos, doses ou tratamentos** e **não comprova o uso** de nenhum remédio. Ele registra apenas o que o usuário informou. Não substitui a orientação de profissionais de saúde nem serviços de emergência.

---

## Sumário

1. [Visão geral](#1-visão-geral)
2. [Funcionalidades](#2-funcionalidades)
3. [Tecnologias](#3-tecnologias)
4. [Estrutura do projeto](#4-estrutura-do-projeto)
5. [Pré-requisitos](#5-pré-requisitos)
6. [Instalação passo a passo (Windows)](#6-instalação-passo-a-passo-windows)
7. [Configuração do Firebase](#7-configuração-do-firebase)
8. [Configuração do Android](#8-configuração-do-android)
9. [Publicar regras, índices e funções](#9-publicar-regras-índices-e-funções)
10. [Rodando o app](#10-rodando-o-app)
11. [App Check](#11-app-check)
12. [Testes](#12-testes)
13. [Modelo de dados do Firestore](#13-modelo-de-dados-do-firestore)
14. [Segurança e privacidade (LGPD)](#14-segurança-e-privacidade-lgpd)
15. [Como funcionam as notificações](#15-como-funcionam-as-notificações)
16. [Funcionamento offline](#16-funcionamento-offline)
17. [Problemas comuns e soluções](#17-problemas-comuns-e-soluções)
18. [Limitações conhecidas e próximos passos](#18-limitações-conhecidas-e-próximos-passos)

---

## 1. Visão geral

O Cuida+ tem dois tipos de usuário:

| Perfil | O que pode fazer |
|---|---|
| **Paciente** | Cadastrar medicamentos e horários, receber lembretes, confirmar/adiar/negar o registro de uso, ver histórico, cadastrar consultas, convidar familiares e controlar o que cada um pode ver. |
| **Familiar / cuidador** | Aceitar convites, ver os pacientes que o autorizaram, acompanhar medicamentos, histórico e consultas conforme as permissões, receber avisos e deixar de acompanhar um paciente. |

O familiar **não altera** nada do paciente. As permissões são validadas no **backend** (Firestore Security Rules e Cloud Functions), e não apenas escondidas na interface.

## 2. Funcionalidades

**Autenticação**
- Cadastro com nome, e-mail e senha; escolha do perfil (paciente ou familiar).
- Login, recuperação de senha, logout e sessão persistente.
- Verificação de e-mail obrigatória para acessar os dados.
- Exclusão de conta com reautenticação e apagamento dos dados no backend.

**Medicamentos**
- Nome, dosagem (informada pelo usuário), forma de apresentação, observações, datas de início e término, situação (ativo/inativo).
- Vários horários por medicamento, sem duplicidade.
- Ativar/desativar lembretes, arquivar (preserva histórico) e excluir.

**Lembretes**
- Notificações locais agendadas no aparelho, mesmo com o app fechado (respeitando as limitações do Android).
- Reagendamento automático quando horários, datas ou situação mudam.
- Opção de adiar a dose por 15 minutos.

**Consultas**
- Profissional, especialidade, local, data, horário, observações e situação.
- Calendário mensal, lista das próximas consultas e lembrete com antecedência configurável (30 min, 1 h, 2 h, 1 dia, 2 dias).

**Histórico**
- Registro por ocorrência: medicamento, horário previsto, situação, horário da confirmação e quem registrou.
- Situações: *Confirmado pelo usuário*, *Pendente*, *Não realizado (informado)* e *Adiado (informado)*.
- Cada alteração gera uma entrada imutável (de/para, autor e data).

**Acompanhamento familiar**
- Convite seguro: código aleatório, guardado apenas como hash, com validade de 7 dias.
- O aceite exige conta de familiar com e-mail verificado e igual ao convidado.
- Cinco permissões por familiar: ver medicamentos, horários, histórico, consultas e receber notificações.
- Revogação do acesso a qualquer momento.

**Notificações remotas (FCM, via Cloud Functions)**
- Confirmação de uso informada pelo paciente.
- Horário sem confirmação (verificação a cada 5 minutos).
- Medicamento cadastrado ou alterado.
- Consulta próxima (24 horas).
- Convite recebido ou aceito.

## 3. Tecnologias

| Área | Tecnologia |
|---|---|
| App | Flutter e Dart |
| Estado | Riverpod |
| Navegação | GoRouter |
| Autenticação | Firebase Authentication |
| Banco de dados | Cloud Firestore |
| Push | Firebase Cloud Messaging |
| Lembretes locais | flutter_local_notifications, timezone, flutter_timezone |
| Proteção | Firebase App Check |
| Monitoramento | Firebase Crashlytics |
| Métricas | Firebase Analytics (somente com consentimento) |
| Backend | Cloud Functions (Node.js 20, funções v2) |
| Datas | intl (pt_BR) |

As dependências do `pubspec.yaml` usam `any`: o `pub` escolhe as versões estáveis compatíveis na hora do `flutter pub get`. Depois do primeiro build bem-sucedido, **mantenha o `pubspec.lock` no controle de versão** para fixar as versões.

## 4. Estrutura do projeto

```
cuida_plus/
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart          # gerado pelo flutterfire configure
│   ├── app/                           # app.dart, routes.dart, app_theme.dart
│   ├── models/permissions.dart
│   ├── core/
│   │   ├── errors/                    # AppException, guard(), mensagens amigáveis
│   │   ├── services/                  # firebase, notificações locais, push (FCM)
│   │   ├── utils/                     # validadores e datas
│   │   └── widgets/                   # carregando, vazio, erro, chips, diálogos
│   └── features/
│       ├── authentication/            # data / domain / presentation
│       ├── home/
│       ├── medications/               # inclui usecase build_daily_doses
│       ├── consultations/
│       ├── reminders/                 # caixa de notificações e sincronização dos lembretes
│       ├── history/
│       ├── family/
│       └── profile/                   # perfil e configurações
├── functions/                         # Cloud Functions (index.js, package.json)
├── test/                              # unit/, widgets/ e rules/ (regras do Firestore)
├── integration_test/                  # teste de permissões com o Emulator Suite
├── android_setup/                     # trechos para o AndroidManifest
├── docs/                              # modelagem do Firestore e política de privacidade
├── firestore.rules
├── firestore.indexes.json
└── firebase.json
```

Cada funcionalidade separa **presentation** (telas e providers), **domain** (entidades e contratos) e **data** (implementações com Firebase). As telas **nunca** consultam o Firestore diretamente: elas usam repositórios injetados por providers, o que permite trocar ou complementar o armazenamento sem reescrever a interface.

## 5. Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal stable) e `flutter doctor` sem erros no item *Android toolchain*.
- [Android Studio](https://developer.android.com/studio) com Android SDK, **Android SDK Command-line Tools** e um emulador ou celular Android com depuração USB.
- [Node.js](https://nodejs.org) LTS (para a Firebase CLI e as Cloud Functions).
- Uma conta Google e um projeto no [Firebase](https://console.firebase.google.com).
- Plano **Blaze** (pago, com cota gratuita) no Firebase para publicar as Cloud Functions.

## 6. Instalação passo a passo (Windows)

> **Dica:** evite pastas dentro do **OneDrive** e caminhos longos ou com espaços (por exemplo `C:\dev\cuida_plus`). O OneDrive pode travar o Gradle durante o build.

```powershell
mkdir C:\dev
cd C:\dev
# extraia o projeto em C:\dev\cuida_plus e entre na pasta
cd cuida_plus

# se a pasta android/ ainda não existir, gere as plataformas
flutter create --project-name cuida_plus --org br.com.seudominio --platforms=android,ios .
```

Se o comando perguntar sobre sobrescrever arquivos, **não aceite**, e confirme depois que `lib\main.dart` continua sendo o do Cuida+. Apague o teste de exemplo gerado pelo Flutter, que não combina com o app:

```powershell
Remove-Item test\widget_test.dart -ErrorAction SilentlyContinue
```

Instale as ferramentas do Firebase:

```powershell
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
```

Se o Windows disser que o comando `flutterfire` não existe, adicione `C:\Users\<seu-usuário>\AppData\Local\Pub\Cache\bin` ao **Path** (Variáveis de Ambiente do Windows) e reabra o terminal. Sem mexer no PATH, use `dart pub global run flutterfire_cli:flutterfire configure`.

Se o PowerShell bloquear scripts, rode uma vez:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

## 7. Configuração do Firebase

### 7.1. Criar e preparar o projeto

No [console do Firebase](https://console.firebase.google.com):

1. **Criar projeto** (por exemplo `cuida-plus`).
2. **Authentication > Método de login:** ative **E-mail/senha**.
3. **Firestore Database > Criar banco de dados:** região **`southamerica-east1` (São Paulo)**, em **modo de produção**. A região não pode ser alterada depois.
4. **Configurações do projeto > Uso e faturamento:** mude para o plano **Blaze** (necessário para as Cloud Functions).
5. **Cloud Messaging**, **Crashlytics** e **Analytics** não precisam de ativação manual.

### 7.2. Ligar o app ao projeto

Na pasta do projeto, descubra o **ID** do projeto (ele tem sufixo, como `cuida-plus-7326b`):

```powershell
firebase projects:list
```

Gere o `firebase_options.dart` e registre o app Android:

```powershell
flutterfire configure --project=SEU_ID_DO_PROJETO --platforms=android --out=lib/firebase_options.dart --yes
```

Se o comando perguntar se deve reaproveitar o `firebase.json`, responda **não**. Confirme que o arquivo foi gerado de verdade:

```powershell
Select-String -Path lib\firebase_options.dart -Pattern "projectId"
Test-Path android\app\google-services.json
```

O primeiro deve mostrar o ID do seu projeto e o segundo deve retornar `True`. Também verifique se o `firebase.json` ainda contém as seções `firestore`, `functions` e `emulators`.

## 8. Configuração do Android

### 8.1. `android/app/src/main/AndroidManifest.xml`

Os trechos prontos estão em `android_setup/AndroidManifest_additions.xml`. Dentro de `<manifest>`, antes de `<application>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

Dentro de `<application>`, junto da `<activity>`:

```xml
<meta-data android:name="firebase_analytics_collection_enabled" android:value="false"/>
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```

Sem esses itens o app abre, mas os lembretes não sobrevivem à reinicialização do celular, o horário pode atrasar e o Analytics ficaria ligado antes do consentimento. Avisos amarelos do editor do Android Studio sobre classes não resolvidas (como `MainActivity` ou `dexterous`) são esperados antes do primeiro build e podem ser ignorados.

### 8.2. `android/app/build.gradle.kts`

```kotlin
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true      // exigido pelo flutter_local_notifications
    }
    defaultConfig {
        minSdk = maxOf(flutter.minSdkVersion, 23)  // o Firebase exige no mínimo 23
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
```

Se o build reclamar do NDK (`ndkVersion`), instale-o em **SDK Manager > SDK Tools > Show Package Details > NDK (Side by side)**. Como o app não usa código nativo próprio, você também pode remover a linha `ndkVersion = flutter.ndkVersion`.

## 9. Publicar regras, índices e funções

Execute **dentro da pasta do projeto** (onde está o `firebase.json`):

```powershell
firebase use SEU_ID_DO_PROJETO
firebase deploy --only firestore:rules,firestore:indexes
```

Sem as regras do projeto, o cadastro falha com `PERMISSION_DENIED` (o banco em modo de produção bloqueia tudo). Os índices levam alguns minutos para ficar **Ativados** (console: *Firestore Database > Índices*). Até lá, telas que listam histórico, consultas e notificações podem mostrar "não foi possível carregar seus dados".

Cloud Functions (exigem o plano Blaze):

```powershell
cd functions
npm install
cd ..
firebase deploy --only functions
```

O Node 24 local não impede o deploy. As funções rodam em Node 20 na nuvem. Sem as funções, cadastro, login, medicamentos, histórico e consultas funcionam, mas **convites, vínculo familiar e notificações para familiares não funcionam**.

## 10. Rodando o app

```powershell
flutter pub get
flutter analyze
flutter devices
flutter run
```

- O `flutter analyze` deve terminar sem `error`. Avisos `info` sobre `getToken`/`onTokenRefresh` depreciados em `push_service.dart` podem ser ignorados.
- Windows, Chrome e Edge **não são suportados**: o app é para Android (e iOS futuramente). Use um emulador (Device Manager do Android Studio) ou um celular com **Depuração USB** ativada (Opções do desenvolvedor).
- O primeiro build do Android demora vários minutos. Os avisos `WARNING` do Java/Gradle sobre métodos restritos são inofensivos.

**Fluxo de teste sugerido**

1. Crie uma conta de **paciente**, abra o link de verificação do e-mail e toque em **Já verifiquei**.
2. No console, confira o usuário em *Authentication* e as coleções `users` e `patients` em *Firestore > Dados*.
3. Cadastre um medicamento com horário daqui a poucos minutos e confira o card em **Hoje** e a notificação.
4. Toque em **Confirmar** e veja o registro em **Histórico**.
5. Com as funções publicadas, crie uma conta de **familiar**, convide-o pelo paciente e aceite o convite.

> A aba **Hoje** cria uma dose para cada horário do dia, inclusive os que já passaram. Se você cadastrar um remédio das 8h depois das 8h30, ele aparece como **Atrasado** (dose pendente há mais de 30 minutos). Isso é esperado. O app usa o horário e o fuso do próprio aparelho.

## 11. App Check

O código usa o provedor **Debug** em desenvolvimento e **Play Integrity** em produção.

**Desenvolvimento**

1. Rode o app em modo debug e procure no log (Logcat) por `DebugAppCheckProvider`. O log mostra o token de depuração.
2. No console: **App Check > Apps >** seu app Android **> Gerenciar tokens de depuração > Adicionar**, e cole o token.
3. Enquanto isso não for feito, o log mostra `Failed to exchange debug token`. Isso só atrapalha se a **imposição (Enforce)** estiver ligada.

**Produção**

1. Em **App Check > Apps**, registre o provedor **Play Integrity** e informe o SHA-256 do certificado de assinatura.
2. O app precisa estar no Google Play (ao menos em teste interno).
3. Só então ative a imposição para Firestore, Authentication e Functions, depois de confirmar nas métricas que as requisições estão verificadas.

O status "faltando registrar" no console é normal até o registro do provedor.

## 12. Testes

```powershell
flutter test                                   # unitários e de widget
```

Regras do Firestore (Emulator Suite; precisa de Java e `firebase-tools`):

```powershell
cd test\rules
npm install
npm test
```

Cobrem: acesso de um usuário a dados de outro, familiar sem vínculo, vínculo revogado, permissão específica negada, cliente tentando criar vínculo/convite, medicamento inválido, e-mail não verificado e histórico não apagável.

Teste de integração (emuladores de Auth e Firestore rodando e um emulador Android):

```powershell
firebase emulators:start --only auth,firestore --project demo-cuida
flutter test integration_test/permissions_flow_test.dart
```

O teste de integração usa o host `10.0.2.2` (o emulador Android enxergando o PC). **Não há testes automatizados das Cloud Functions.**

## 13. Modelo de dados do Firestore

Detalhes completos e exemplos de documentos em [`docs/MODELAGEM_FIRESTORE.md`](docs/MODELAGEM_FIRESTORE.md). Resumo:

| Coleção | Chave do documento | Quem escreve |
|---|---|---|
| `users` | uid | o próprio usuário (papel imutável) |
| `patients` | uid do paciente | o próprio paciente |
| `medications` | automático | paciente |
| `medication_schedules` | `{medicationId}_{HHmm}` | paciente |
| `medication_logs` | `{scheduleId}_{yyyyMMdd}` | paciente (e a função, para pendências) |
| `medication_logs/{id}/changes` | automático | paciente (somente criação) |
| `consultations` | automático | paciente |
| `family_relationships` | `{patientId}_{caregiverUid}` | **somente Cloud Functions** (paciente altera permissões/revoga) |
| `invitations` | automático | **somente Cloud Functions** |
| `notification_preferences` | uid | o próprio usuário |
| `device_tokens` | `{uid}_{sha256(token)}` | o próprio usuário |
| `notifications` | automático | **somente Cloud Functions** |
| `notification_events` | `{chave}_{uid}` | **somente Cloud Functions** (idempotência) |

Pontos de projeto:
- IDs determinísticos em horários e registros impedem duplicidade.
- Datas em `Timestamp`; as chaves `yyyyMMdd` nos horários permitem à função respeitar início e término no fuso do paciente.
- O histórico não pode ser apagado pelo cliente.
- Índices compostos em `firestore.indexes.json`: `medication_logs(patientId, scheduledAt)`, `consultations(patientId, dateTime)`, `consultations(status, dateTime)` e `notifications(userId, createdAt)`.

## 14. Segurança e privacidade (LGPD)

- **Autenticação** com e-mail verificado; senhas ficam apenas no Firebase Authentication, nunca no Firestore.
- **Firestore Security Rules restritivas:** só o dono lê seus dados; o familiar lê apenas com vínculo ativo **e** a permissão específica. Vínculos e convites só são criados pelo backend.
- **Convites:** código de 64 bits, armazenado como SHA-256, validade de 7 dias, aceite condicionado ao e-mail verificado correspondente.
- **Idempotência:** `notification_events` com `create()` evita notificações duplicadas, inclusive em reentrega de eventos.
- **Sem credenciais administrativas no app:** o Admin SDK só roda nas Cloud Functions.
- **Validação** nos campos do cliente e nas regras do banco.
- **Privacidade:** Analytics desligado por padrão e ativado apenas com consentimento; consentimento no cadastro; exportação (*Configurações > Exportar meus dados*); exclusão da conta e de todos os dados (*Perfil > Excluir minha conta*); revogação de acesso por familiar.
- **Logs sem dados sensíveis:** as mensagens de erro exibidas ao usuário são genéricas e o Crashlytics recebe apenas as exceções.
- **Política de privacidade:** o modelo em [`docs/POLITICA_PRIVACIDADE.md`](docs/POLITICA_PRIVACIDADE.md) **precisa de revisão jurídica** e do preenchimento dos campos entre colchetes antes da publicação. Medicamentos e consultas são **dados pessoais sensíveis (saúde)**.

## 15. Como funcionam as notificações

**Locais (no aparelho)**
- Agendadas pelo `NotificationService` a cada alteração de medicamentos, horários ou consultas; o agendamento é cancelado e recriado, com IDs estáveis (sem duplicatas).
- Medicamento **sem data de término**: repetição diária nativa. **Com data de término**: um agendamento por dia, até 60 dias por horário, recalculados quando o app abre.
- Após reiniciar o celular, o receiver de boot recria os alarmes.
- Alarmes **exatos** exigem a permissão especial do Android 12+ (*Configurações > Permitir alarmes exatos*); sem ela, o lembrete pode atrasar alguns minutos.
- Fabricantes como Xiaomi e Samsung podem restringir apps em segundo plano. Se os lembretes falharem, retire a restrição de bateria do Cuida+.

**Remotas (FCM, enviadas por Cloud Functions)**
- O FCM não agenda nada sozinho: o disparo é feito pelo backend (gatilhos de documentos e funções agendadas), sem depender do app aberto.
- O token do aparelho é salvo em `device_tokens` e removido ao sair da conta.
- O familiar só recebe se tiver vínculo ativo e a permissão *Receber notificações* (e a de ver o dado correspondente).

## 16. Funcionamento offline

- O Firestore usa cache persistente e fila de escritas: dados já carregados continuam visíveis, e alterações feitas offline são sincronizadas ao reconectar.
- Itens ainda não confirmados pelo servidor mostram um ícone de nuvem ("aguardando sincronização").
- Operações de escrita têm timeout de 8 segundos; offline, o app avisa que a alteração foi salva no aparelho.
- Conflitos: nos cadastros vale a última gravação; nos registros de uso, o ID determinístico com `merge` evita duplicatas e a trilha `changes` preserva cada ação.
- **Não há camada de banco local separada** (por exemplo SQLite). O cache do Firestore não substitui todos os cenários offline. Se precisar de operação offline mais pesada, planeje essa camada à parte.

## 17. Problemas comuns e soluções

| Sintoma | Causa provável | Solução |
|---|---|---|
| `firebase`, `flutterfire` ou `dart` não reconhecidos | Ferramenta não instalada ou fora do PATH | Instale e reabra o terminal; veja a seção 6 |
| `firebase use` pede `firebase init` | Comando executado fora da pasta do projeto | `cd` até a pasta com o `firebase.json` |
| App fecha ou erra ao iniciar com `UnsupportedError` | `firebase_options.dart` ainda é o placeholder | Rode `flutterfire configure` (seção 7.2) |
| "No supported devices connected" | Nenhum emulador/celular Android | Crie um emulador ou ative a depuração USB |
| Build falha: NDK não instalado | Gradle não conseguiu baixar o NDK | Instale o NDK no SDK Manager ou remova `ndkVersion` |
| Build falha: desugaring | Opção não ativada | Veja a seção 8.2 |
| Erro ao cadastrar, `PERMISSION_DENIED` em `users`/`patients` | Regras do Firestore não publicadas | `firebase deploy --only firestore:rules,firestore:indexes` |
| "Não foi possível carregar seus dados" na aba Hoje | Índices ainda em criação, e-mail não verificado ou sem conexão | Aguarde os índices ficarem Ativados; toque em **Já verifiquei**; veja o log do `flutter run` |
| `FAILED_PRECONDITION: requires an index` | Falta um índice composto | Use o link da mensagem ou publique `firestore.indexes.json` |
| `Failed to exchange debug token` | Token do App Check não registrado | Seção 11 (só atrapalha com *Enforce* ligado) |
| Dose aparece como "Atrasado" | Passaram 30 min do horário sem confirmar | Comportamento esperado; toque em **Confirmar** |
| Horário errado no emulador | Fuso do emulador diferente do seu | Ajuste *Data e hora* dentro do emulador e reinicie o app |
| Convites e avisos para familiares não funcionam | Cloud Functions não publicadas | Plano Blaze e `firebase deploy --only functions` |
| Erros em `flutter_local_notifications` ou `firebase_app_check` após atualizar pacotes | APIs mudaram entre versões maiores | Ajuste conforme o erro do compilador ou fixe versões no `pubspec.yaml` |

## 18. Limitações conhecidas e próximos passos

- **Convite por e-mail:** o app mostra o código para o paciente compartilhar. Não há envio de e-mail; integre um provedor (ou a extensão *Trigger Email*). Se o convidado já tem conta, recebe uma notificação.
- **iOS:** a arquitetura permite, mas faltam configuração do Xcode, APNs, permissões e testes.
- **Escalabilidade:** a função `checkMissedDoses` varre todos os horários ativos a cada 5 minutos, adequado para um MVP; para volume maior, particione por horário ou fuso.
- **Testes:** não há testes automatizados das Cloud Functions, e o teste de integração cobre só o fluxo de permissões.
- **Crashlytics:** o plugin Gradle do Crashlytics (símbolos de falhas nativas) não está configurado. Os erros de Dart são reportados normalmente.
- **Publicação:** configure a assinatura de release, ícone e nome do app, ative o App Check com Play Integrity, revise a política de privacidade com um(a) advogado(a) e, se necessário, designe um encarregado (DPO).
- **Notificações:** lembretes de medicamentos com data de término são agendados dia a dia (até 60 dias) e dependem de o app ser aberto de tempos em tempos para renovar.

---

*O Cuida+ é um apoio à organização de rotinas de cuidado e não substitui a orientação de profissionais de saúde.*
