# Modelagem do Firestore — Cuida+

Local recomendado do banco: `southamerica-east1` (São Paulo), igual às Cloud Functions.
Datas sempre como `Timestamp` (UTC). `patientId` = UID do paciente (dono dos dados).
Escritas sensíveis (vínculos, convites, notificações) são feitas **somente pelo backend**; o cliente não consegue criá-las (ver `firestore.rules`).

## users/{uid}
```json
{ "name": "Maria Silva", "email": "maria@exemplo.com", "role": "patient",
  "analyticsConsent": false, "termsAcceptedAt": "<Timestamp>", "createdAt": "<Timestamp>" }
```
- `role`: `patient` | `caregiver`. Imutável após criação (regra). `email` imutável e igual ao do token.
- `analyticsConsent`: consentimento (LGPD) para Firebase Analytics. Padrão `false`.
- `termsAcceptedAt`: registro do aceite da política (prova de consentimento).
- Senha **nunca** é armazenada (Firebase Authentication).

## patients/{uid}
`{ ownerUid, name, createdAt }` — perfil do paciente. Legível por familiares com vínculo ativo.

## medications/{id}
```json
{ "patientId": "uid", "name": "Medicamento A", "dosage": "Conforme prescrição", "form": "Comprimido",
  "notes": "", "startDate": "<Timestamp>", "endDate": null, "active": true,
  "remindersEnabled": true, "archived": false, "createdAt": "…", "updatedAt": "…" }
```
- Texto informado pelo usuário; o app não sugere medicamentos nem doses.
- `archived=true` = arquivado (não gera lembretes, preserva histórico). Exclusão definitiva remove medicamento + horários; **logs permanecem**.
- Leitura: dono, ou familiar com `canViewMedications`.

## medication_schedules/{medicationId}_{HHmm}
```json
{ "patientId": "uid", "medicationId": "abc", "hour": 8, "minute": 0, "timezone": "America/Fortaleza",
  "active": true, "startDateKey": "20250610", "endDateKey": null, "updatedAt": "…" }
```
- ID determinístico ⇒ impossível haver dois horários iguais para o mesmo medicamento.
- `active` = medicamento ativo ∧ lembretes ligados ∧ não arquivado (desnormalizado para a Cloud Function não precisar ler o medicamento).
- `startDateKey/endDateKey` (`yyyyMMdd`) permitem à função respeitar o período do tratamento no fuso do paciente.
- Leitura: dono, ou familiar com `canViewSchedules`.

## medication_logs/{scheduleId}_{yyyyMMdd}
```json
{ "patientId": "uid", "medicationId": "abc", "scheduleId": "abc_0800", "medicationName": "Medicamento A",
  "scheduledAt": "<Timestamp>", "status": "confirmed", "confirmedAt": "<Timestamp>|null",
  "actorUid": "uid", "actorName": "Maria", "updatedAt": "…" }
```
- ID determinístico ⇒ **um único registro por paciente/horário/dia** (idempotência, também para a função `checkMissedDoses`).
- `status`: `confirmed` | `pending` | `not_done` | `postponed` — **o que o usuário informou**, não prova de ingestão.
- `actorUid = "system"` quando criado pela função como `pending`.
- Subcoleção **`changes/{auto}`**: `{from, to, actorUid, actorName, at}` — trilha imutável (não pode ser editada/apagada). Logs não podem ser excluídos pelo cliente.
- Leitura: dono, ou familiar com `canViewHistory`.

## consultations/{id}
`{ patientId, professional, specialty, location, notes, dateTime, status(scheduled|done|cancelled), reminderMinutes, createdAt, updatedAt }`
Leitura: dono, ou familiar com `canViewConsultations`.

## family_relationships/{patientId}_{caregiverUid}
```json
{ "patientId": "p", "patientName": "Maria", "caregiverUid": "c", "caregiverName": "João", "caregiverEmail": "joao@…",
  "status": "active", "permissions": { "canViewMedications": true, "canViewSchedules": true, "canViewHistory": true,
  "canReceiveNotifications": true, "canViewConsultations": true }, "invitationId": "…", "createdAt": "…", "updatedAt": "…" }
```
- Criado **apenas** pela função `acceptInvitation`. Paciente altera `permissions` e revoga (`status: revoked`); familiar só pode sair (`left`). `revoked`/`left` não reativam.
- Regras do Firestore e funções consultam este documento para autorizar leitura.

## invitations/{id}
`{ patientId, patientName, email, tokenHash, status(pending|accepted|cancelled), createdAt, expiresAt, acceptedBy?, acceptedAt? }`
- Código aleatório de 64 bits mostrado **uma vez** ao paciente; guarda-se apenas `sha256` (`tokenHash`). Validade de 7 dias. Aceite exige e-mail verificado **igual** ao convidado.

## notification_preferences/{uid} → `{ enabled: bool, updatedAt }`
## device_tokens/{uid}_{sha256(token)} → `{ uid, token, platform, updatedAt }` (somente o dono lê/grava; tokens inválidos são removidos pela função)
## notifications/{id} → caixa de entrada in-app `{ userId, title, body, data, read, createdAt }` (criada só pelo backend; usuário só marca `read`)
## notification_events/{key}_{uid} → trava de idempotência (acesso negado ao cliente). `create()` falha se já existe ⇒ nenhuma notificação duplicada, inclusive em reentregas de eventos.

## Índices (`firestore.indexes.json`)
`medication_logs(patientId ↑, scheduledAt ↓)`, `consultations(patientId ↑, dateTime ↑)`, `consultations(status ↑, dateTime ↑)`, `notifications(userId ↑, createdAt ↓)`.

## Exclusão, arquivamento e sincronização
- Arquivar medicamento preserva histórico. Exclusão de conta: função `deleteMyData` (recursiva) + `user.delete()` no cliente após reautenticação.
- Offline: cache persistente do Firestore + escritas em fila; a UI mostra o ícone de nuvem nos itens `hasPendingWrites`. Conflitos: último-a-gravar vence nos cadastros; nos registros de uso o ID determinístico + `merge` evita duplicatas e a trilha `changes` preserva cada ação.
