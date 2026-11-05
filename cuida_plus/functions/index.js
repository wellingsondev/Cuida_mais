'use strict';
/**
 * Cuida+ — backend confiável (Cloud Functions v2).
 * - Convites seguros (createInvitation / acceptInvitation)
 * - Notificações remotas via FCM com idempotência (notification_events)
 * - Verificação periódica de doses sem registro e consultas próximas
 * - Exclusão e exportação de dados (LGPD)
 * Nenhuma credencial é necessária no app: o Admin SDK usa a identidade da função.
 */
const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
setGlobalOptions({ region: 'southamerica-east1', maxInstances: 10 });
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const GRACE_MINUTES = 30;          // tolerância antes de considerar "sem confirmação"
const MISSED_WINDOW_MINUTES = 720; // não cria pendências além de 12h após o horário
const INVITE_TTL_MS = 7 * 24 * 3600 * 1000;
const PERMS = ['canViewMedications', 'canViewSchedules', 'canViewHistory', 'canReceiveNotifications', 'canViewConsultations'];

const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');
const requireAuth = (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Faça login para continuar.');
  if (req.auth.token.email_verified !== true) throw new HttpsError('failed-precondition', 'Verifique seu e-mail antes de continuar.');
  return req.auth.uid;
};
const userDoc = async (uid) => (await db.doc(`users/${uid}`).get()).data();

// ---------- notificação com idempotência ----------
async function notifyOnce({ uid, key, title, body, data = {} }) {
  const guard = db.doc(`notification_events/${key}_${uid}`);
  try {
    await guard.create({ createdAt: FieldValue.serverTimestamp() });
  } catch (e) {
    if (e.code === 6 || /ALREADY_EXISTS/.test(String(e))) return false; // já enviada
    throw e;
  }
  await db.collection('notifications').add({ userId: uid, title, body, data, read: false, createdAt: FieldValue.serverTimestamp() });
  const prefs = await db.doc(`notification_preferences/${uid}`).get();
  if (prefs.exists && prefs.data().enabled === false) return true;
  const snap = await db.collection('device_tokens').where('uid', '==', uid).get();
  if (snap.empty) return true;
  const tokens = snap.docs.map((d) => d.data().token);
  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    android: { priority: 'high' },
  });
  const dead = [];
  res.responses.forEach((r, i) => {
    const c = r.error && r.error.code;
    if (c === 'messaging/registration-token-not-registered' || c === 'messaging/invalid-registration-token') dead.push(snap.docs[i].ref.delete());
  });
  await Promise.all(dead);
  return true;
}

async function notifyCaregivers(patientId, perms, payload) {
  const rels = await db.collection('family_relationships').where('patientId', '==', patientId).where('status', '==', 'active').get();
  const jobs = rels.docs
    .map((d) => d.data())
    .filter((r) => perms.every((p) => r.permissions && r.permissions[p] === true))
    .map((r) => notifyOnce({ uid: r.caregiverUid, ...payload, data: { ...(payload.data || {}), patientId } }));
  await Promise.all(jobs);
}

// ---------- convites ----------
exports.createInvitation = onCall(async (req) => {
  const uid = requireAuth(req);
  const me = await userDoc(uid);
  if (!me || me.role !== 'patient') throw new HttpsError('permission-denied', 'Apenas pacientes podem convidar.');
  const email = String(req.data.email || '').trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 254) throw new HttpsError('invalid-argument', 'E-mail inválido.');
  if (email === (req.auth.token.email || '').toLowerCase()) throw new HttpsError('invalid-argument', 'Você não pode convidar a si mesmo.');
  const pending = await db.collection('invitations').where('patientId', '==', uid).where('status', '==', 'pending').get();
  if (pending.size >= 10) throw new HttpsError('resource-exhausted', 'Limite de convites pendentes atingido.');
  const code = crypto.randomBytes(8).toString('hex').toUpperCase(); // 64 bits de entropia
  const ref = db.collection('invitations').doc();
  const expiresAt = Timestamp.fromMillis(Date.now() + INVITE_TTL_MS);
  await ref.set({ patientId: uid, patientName: me.name, email, tokenHash: sha256(code), status: 'pending', createdAt: FieldValue.serverTimestamp(), expiresAt });
  try {
    const target = await admin.auth().getUserByEmail(email);
    await notifyOnce({ uid: target.uid, key: `invite_${ref.id}`, title: 'Convite de acompanhamento', body: `${me.name} convidou você para acompanhar os cuidados.`, data: { type: 'invite', invitationId: ref.id } });
  } catch (e) { if (e.code !== 'auth/user-not-found') console.error('invite notify failed', e.code); }
  return { invitationId: ref.id, code, expiresAt: expiresAt.toMillis() };
});

exports.acceptInvitation = onCall(async (req) => {
  const uid = requireAuth(req);
  const me = await userDoc(uid);
  if (!me || me.role !== 'caregiver') throw new HttpsError('permission-denied', 'Apenas contas de familiar/cuidador podem aceitar convites.');
  const email = (req.auth.token.email || '').toLowerCase();
  const code = req.data.code ? String(req.data.code).trim().toUpperCase() : null;
  let ref;
  if (req.data.invitationId) ref = db.doc(`invitations/${String(req.data.invitationId)}`);
  else if (code) {
    const q = await db.collection('invitations').where('tokenHash', '==', sha256(code)).limit(1).get();
    if (q.empty) throw new HttpsError('not-found', 'Convite inválido ou expirado.');
    ref = q.docs[0].ref;
  } else throw new HttpsError('invalid-argument', 'Informe o convite.');

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const inv = snap.data();
    if (!snap.exists || inv.status !== 'pending' || inv.expiresAt.toMillis() < Date.now()) throw new HttpsError('failed-precondition', 'Convite inválido ou expirado.');
    if (inv.email !== email) throw new HttpsError('permission-denied', 'Este convite foi enviado para outro e-mail.');
    if (code && !crypto.timingSafeEqual(Buffer.from(sha256(code)), Buffer.from(inv.tokenHash))) throw new HttpsError('permission-denied', 'Código incorreto.');
    const relRef = db.doc(`family_relationships/${inv.patientId}_${uid}`);
    tx.set(relRef, {
      patientId: inv.patientId, patientName: inv.patientName, caregiverUid: uid, caregiverName: me.name, caregiverEmail: email,
      status: 'active', permissions: Object.fromEntries(PERMS.map((p) => [p, true])),
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(), invitationId: ref.id,
    });
    tx.update(ref, { status: 'accepted', acceptedBy: uid, acceptedAt: FieldValue.serverTimestamp() });
    req.__patientId = inv.patientId;
  });
  await notifyOnce({ uid: req.__patientId, key: `accepted_${ref.id}`, title: 'Convite aceito', body: `${me.name} agora acompanha seus cuidados.`, data: { type: 'invite_accepted' } });
  return { ok: true };
});

// ---------- gatilhos de notificação ----------
exports.onLogWritten = onDocumentWritten('medication_logs/{id}', async (event) => {
  const after = event.data.after.data();
  const before = event.data.before.data();
  if (!after || after.status !== 'confirmed' || (before && before.status === 'confirmed')) return;
  const patient = await userDoc(after.patientId);
  await notifyCaregivers(after.patientId, ['canReceiveNotifications', 'canViewHistory'], {
    key: `confirmed_${event.params.id}`, title: 'Registro de uso informado',
    body: `${patient ? patient.name : 'O paciente'} informou o uso de ${after.medicationName}.`, data: { type: 'confirmed', logId: event.params.id },
  });
});

exports.onMedicationWritten = onDocumentWritten('medications/{id}', async (event) => {
  const after = event.data.after.data();
  const before = event.data.before.data();
  if (!after) return;
  const relevant = !before || ['name', 'dosage', 'active', 'endDate'].some((k) => String(before[k]) !== String(after[k]));
  if (!relevant) return;
  const patient = await userDoc(after.patientId);
  await notifyCaregivers(after.patientId, ['canReceiveNotifications', 'canViewMedications'], {
    key: `med_${event.id}`, title: before ? 'Medicamento atualizado' : 'Novo medicamento cadastrado',
    body: `${patient ? patient.name : 'O paciente'}: ${after.name}.`, data: { type: 'medication', medicationId: event.params.id },
  });
});

// ---------- verificações agendadas ----------
function localParts(tz, date = new Date()) {
  const f = new Intl.DateTimeFormat('en-CA', { timeZone: tz, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' });
  const p = Object.fromEntries(f.formatToParts(date).map((x) => [x.type, x.value]));
  return { key: `${p.year}${p.month}${p.day}`, minutes: Number(p.hour) * 60 + Number(p.minute) };
}

exports.checkMissedDoses = onSchedule('every 5 minutes', async () => {
  const scheds = await db.collection('medication_schedules').where('active', '==', true).get();
  for (const doc of scheds.docs) {
    const s = doc.data();
    let now;
    try { now = localParts(s.timezone || 'America/Sao_Paulo'); } catch { continue; }
    const at = s.hour * 60 + s.minute;
    const late = now.minutes - at;
    if (late < GRACE_MINUTES || late > MISSED_WINDOW_MINUTES) continue;
    if (s.startDateKey && now.key < s.startDateKey) continue;
    if (s.endDateKey && now.key > s.endDateKey) continue;
    const logRef = db.doc(`medication_logs/${doc.id}_${now.key}`);
    const med = (await db.doc(`medications/${s.medicationId}`).get()).data();
    if (!med) continue;
    try {
      await logRef.create({
        patientId: s.patientId, medicationId: s.medicationId, scheduleId: doc.id, medicationName: med.name,
        scheduledAt: Timestamp.fromMillis(Math.floor(Date.now() / 60000) * 60000 - late * 60000),
        status: 'pending', confirmedAt: null, actorUid: 'system', actorName: 'Sistema', updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (e) { continue; } // já existe registro (confirmado/pendente) => idempotente
    const patient = await userDoc(s.patientId);
    await notifyCaregivers(s.patientId, ['canReceiveNotifications', 'canViewHistory'], {
      key: `missed_${logRef.id}`, title: 'Horário sem confirmação',
      body: `${patient ? patient.name : 'O paciente'} ainda não registrou ${med.name} das ${String(s.hour).padStart(2, '0')}:${String(s.minute).padStart(2, '0')}.`,
      data: { type: 'missed', logId: logRef.id },
    });
  }
});

exports.checkUpcomingConsultations = onSchedule('every 30 minutes', async () => {
  const from = Timestamp.now();
  const to = Timestamp.fromMillis(Date.now() + 24 * 3600 * 1000);
  const q = await db.collection('consultations').where('status', '==', 'scheduled').where('dateTime', '>=', from).where('dateTime', '<=', to).get();
  for (const d of q.docs) {
    const c = d.data();
    const patient = await userDoc(c.patientId);
    await notifyCaregivers(c.patientId, ['canReceiveNotifications', 'canViewConsultations'], {
      key: `consult24_${d.id}`, title: 'Consulta próxima',
      body: `${patient ? patient.name : 'O paciente'} tem consulta com ${c.professional} em breve.`, data: { type: 'consultation', consultationId: d.id },
    });
  }
});

// ---------- LGPD: exclusão e exportação ----------
async function deleteQuery(q) {
  const snap = await q.get();
  await Promise.all(snap.docs.map((d) => db.recursiveDelete(d.ref)));
}
exports.deleteMyData = onCall(async (req) => {
  const uid = requireAuth(req);
  const email = (req.auth.token.email || '').toLowerCase();
  for (const c of ['medications', 'medication_schedules', 'medication_logs', 'consultations', 'invitations']) {
    await deleteQuery(db.collection(c).where('patientId', '==', uid));
  }
  await deleteQuery(db.collection('family_relationships').where('caregiverUid', '==', uid));
  await deleteQuery(db.collection('invitations').where('email', '==', email));
  await deleteQuery(db.collection('notifications').where('userId', '==', uid));
  await deleteQuery(db.collection('device_tokens').where('uid', '==', uid));
  await Promise.all([db.doc(`notification_preferences/${uid}`), db.doc(`patients/${uid}`), db.doc(`users/${uid}`)].map((r) => db.recursiveDelete(r)));
  console.log('account data deleted', { uid }); // sem dados sensíveis nos logs
  return { ok: true };
});

const plain = (v) => JSON.parse(JSON.stringify(v, (k, x) => (x && x._seconds !== undefined ? new Date(x._seconds * 1000).toISOString() : x)));
exports.exportMyData = onCall(async (req) => {
  const uid = requireAuth(req);
  const out = { exportedAt: new Date().toISOString(), user: plain(await userDoc(uid)) };
  for (const c of ['medications', 'medication_schedules', 'medication_logs', 'consultations']) {
    out[c] = (await db.collection(c).where('patientId', '==', uid).get()).docs.map((d) => plain({ id: d.id, ...d.data() }));
  }
  out.family = (await db.collection('family_relationships').where('patientId', '==', uid).get()).docs.map((d) => plain({ id: d.id, ...d.data() }));
  return out;
});
