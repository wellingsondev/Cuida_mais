// Executar: cd test/rules && npm i && npm test   (usa Firebase Emulator Suite)
import { test, before, after, beforeEach } from 'node:test';
import fs from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, getDocs, collection, query, where, updateDoc, Timestamp } from 'firebase/firestore';

let env;
const ok = { email_verified: true };
const med = (pid, extra = {}) => ({ patientId: pid, name: 'Medicamento A', dosage: 'Conforme prescrição', form: 'Comprimido', notes: '',
  startDate: Timestamp.now(), endDate: null, active: true, remindersEnabled: true, archived: false, ...extra });
const rel = (status = 'active', perms = {}) => ({ patientId: 'pac', caregiverUid: 'fam', status,
  permissions: { canViewMedications: true, canViewSchedules: true, canViewHistory: true, canReceiveNotifications: true, canViewConsultations: true, ...perms } });

before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-cuida', firestore: { rules: fs.readFileSync('../../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 } });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (c) => {
    const d = c.firestore();
    await setDoc(doc(d, 'medications/m1'), med('pac'));
    await setDoc(doc(d, 'family_relationships/pac_fam'), rel());
  });
});
const as = (uid, claims = ok) => env.authenticatedContext(uid, claims).firestore();

test('paciente lê e cria o próprio medicamento', async () => {
  await assertSucceeds(getDoc(doc(as('pac'), 'medications/m1')));
  await assertSucceeds(setDoc(doc(as('pac'), 'medications/m2'), med('pac')));
});
test('usuário não acessa dados de outro paciente', async () => {
  await assertFails(getDoc(doc(as('intruso'), 'medications/m1')));
  await assertFails(getDocs(query(collection(as('intruso'), 'medications'), where('patientId', '==', 'pac'))));
  await assertFails(setDoc(doc(as('intruso'), 'medications/m3'), med('pac')));
});
test('e-mail não verificado é bloqueado', async () => {
  await assertFails(getDoc(doc(as('pac', { email_verified: false }), 'medications/m1')));
});
test('familiar com vínculo ativo lê, mas não altera', async () => {
  await assertSucceeds(getDocs(query(collection(as('fam'), 'medications'), where('patientId', '==', 'pac'))));
  await assertFails(updateDoc(doc(as('fam'), 'medications/m1'), { name: 'X' }));
});
test('familiar sem convite válido não lê', async () => {
  await assertFails(getDoc(doc(as('estranho'), 'medications/m1')));
});
test('permissão específica negada impede leitura', async () => {
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'family_relationships/pac_fam'), rel('active', { canViewMedications: false })));
  await assertFails(getDoc(doc(as('fam'), 'medications/m1')));
});
test('vínculo revogado perde acesso', async () => {
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'family_relationships/pac_fam'), rel('revoked')));
  await assertFails(getDoc(doc(as('fam'), 'medications/m1')));
});
test('cliente não cria vínculo nem convite', async () => {
  await assertFails(setDoc(doc(as('fam'), 'family_relationships/pac_fam2'), rel()));
  await assertFails(setDoc(doc(as('pac'), 'invitations/i1'), { patientId: 'pac', email: 'a@b.c', status: 'pending' }));
});
test('paciente revoga; familiar não se auto-promove', async () => {
  await assertSucceeds(updateDoc(doc(as('pac'), 'family_relationships/pac_fam'), { status: 'revoked' }));
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'family_relationships/pac_fam'), rel()));
  await assertFails(updateDoc(doc(as('fam'), 'family_relationships/pac_fam'), { 'permissions.canViewHistory': true, status: 'active' }));
});
test('medicamento inválido é rejeitado', async () => {
  await assertFails(setDoc(doc(as('pac'), 'medications/bad'), med('pac', { name: '' })));
  await assertFails(setDoc(doc(as('pac'), 'medications/bad2'), med('pac', { endDate: Timestamp.fromMillis(0) })));
});
test('histórico não pode ser apagado', async () => {
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'medication_logs/l1'), { patientId: 'pac', status: 'pending', scheduledAt: Timestamp.now(), actorUid: 'pac', medicationName: 'A' }));
  const { deleteDoc } = await import('firebase/firestore');
  await assertFails(deleteDoc(doc(as('pac'), 'medication_logs/l1')));
});
