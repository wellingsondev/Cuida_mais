import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/medication.dart';
import '../providers/medication_providers.dart';

class MedicationFormScreen extends ConsumerStatefulWidget {
  final String? medicationId;
  const MedicationFormScreen({super.key, this.medicationId});
  @override
  ConsumerState<MedicationFormScreen> createState() => _State();
}

class _State extends ConsumerState<MedicationFormScreen> {
  static const forms = ['Comprimido', 'Cápsula', 'Líquido', 'Gotas', 'Injeção', 'Pomada', 'Spray', 'Outro'];
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController(), _dosage = TextEditingController(), _notes = TextEditingController();
  String _form = forms.first;
  DateTime _start = dateOnly(DateTime.now());
  DateTime? _end;
  List<ScheduleTime> _times = [];
  Medication? _editing;
  bool _loaded = false, _busy = false;

  void _load(List<Medication> meds, List<MedSchedule> scheds) {
    if (_loaded) return;
    _loaded = true;
    final m = meds.where((x) => x.id == widget.medicationId).firstOrNull;
    if (m == null) return;
    _editing = m;
    _name.text = m.name; _dosage.text = m.dosage; _notes.text = m.notes;
    _form = forms.contains(m.form) ? m.form : forms.first;
    _start = m.startDate; _end = m.endDate;
    _times = [for (final s in scheds.where((s) => s.medicationId == m.id)) (hour: s.hour, minute: s.minute)];
  }

  Future<void> _addTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0), builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!));
    if (t == null) return;
    if (!Validators.isValidTime(t.hour, t.minute)) return;
    if (_times.any((x) => x.hour == t.hour && x.minute == t.minute)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este horário já foi adicionado.')));
      return;
    }
    setState(() => _times = [..._times, (hour: t.hour, minute: t.minute)]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute)));
  }

  Future<void> _pickDate(bool start) async {
    final d = await showDatePicker(context: context, initialDate: (start ? _start : _end) ?? _start, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d == null) return;
    setState(() => start ? _start = d : _end = d);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (_times.isEmpty) return _snack('Adicione ao menos um horário.');
    if (_end != null && _end!.isBefore(_start)) return _snack('A data de término não pode ser anterior ao início.');
    final uid = ref.read(currentUidProvider)!;
    final med = Medication(
      id: _editing?.id ?? '', patientId: uid, name: _name.text, dosage: _dosage.text, form: _form, notes: _notes.text,
      startDate: _start, endDate: _end, active: _editing?.active ?? true, remindersEnabled: _editing?.remindersEnabled ?? true, archived: _editing?.archived ?? false,
    );
    setState(() => _busy = true);
    final ok = await runAction(context, () => ref.read(medicationRepositoryProvider).save(med, _times, NotificationService.instance.timezoneName), success: 'Medicamento salvo.');
    if (mounted) {
      setState(() => _busy = false);
      if (ok) context.pop();
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider)!;
    final meds = ref.watch(medicationsProvider(uid));
    final scheds = ref.watch(schedulesProvider(uid));
    if (widget.medicationId != null && (!meds.hasValue || !scheds.hasValue)) return Scaffold(appBar: AppBar(), body: const LoadingView());
    _load(meds.value ?? [], scheds.value ?? []);

    return Scaffold(
      appBar: AppBar(title: Text(_editing == null ? 'Novo medicamento' : 'Editar medicamento')),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nome do medicamento'), validator: (v) => Validators.required(v, 'Nome') ?? Validators.maxLen(v, 100)),
          const SizedBox(height: 14),
          TextFormField(controller: _dosage, decoration: const InputDecoration(labelText: 'Dosagem', helperText: 'Informe conforme a prescrição. Ex.: "Conforme prescrição"'), validator: (v) => Validators.required(v, 'Dosagem') ?? Validators.maxLen(v, 100)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(initialValue: _form, decoration: const InputDecoration(labelText: 'Forma de apresentação'), items: [for (final f in forms) DropdownMenuItem(value: f, child: Text(f))], onChanged: (v) => setState(() => _form = v ?? _form)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(true), icon: const Icon(Icons.event), label: Text('Início: ${fmtDate(_start)}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(false), icon: const Icon(Icons.event_busy), label: Text(_end == null ? 'Sem término' : 'Fim: ${fmtDate(_end!)}'))),
          ]),
          if (_end != null) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => _end = null), child: const Text('Remover data de término'))),
          const SizedBox(height: 14),
          TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Observações (opcional)'), validator: (v) => Validators.maxLen(v, 1000)),
          const SizedBox(height: 20),
          Text('Horários', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in _times)
              InputChip(label: Text('${two(t.hour)}:${two(t.minute)}', style: const TextStyle(fontSize: 16)), onDeleted: () => setState(() => _times = _times.where((x) => x != t).toList())),
            ActionChip(avatar: const Icon(Icons.add_alarm), label: const Text('Adicionar horário'), onPressed: _addTime),
          ]),
          const SizedBox(height: 28),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Salvando...' : 'Salvar')),
        ]),
      ),
    );
  }
}
