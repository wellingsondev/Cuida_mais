import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/consultation.dart';
import '../providers/consultation_providers.dart';

class ConsultationFormScreen extends ConsumerStatefulWidget {
  final String? consultationId;
  final DateTime? initialDate;
  const ConsultationFormScreen({super.key, this.consultationId, this.initialDate});
  @override
  ConsumerState<ConsultationFormScreen> createState() => _State();
}

class _State extends ConsumerState<ConsultationFormScreen> {
  static const leads = {30: '30 minutos antes', 60: '1 hora antes', 120: '2 horas antes', 1440: '1 dia antes', 2880: '2 dias antes'};
  final _key = GlobalKey<FormState>();
  final _pro = TextEditingController(), _spec = TextEditingController(), _loc = TextEditingController(), _notes = TextEditingController();
  late DateTime _date = widget.initialDate ?? dateOnly(DateTime.now());
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  String _status = 'scheduled';
  int _lead = 60;
  Consultation? _editing;
  bool _loaded = false;

  void _load(List<Consultation> list) {
    if (_loaded) return;
    _loaded = true;
    final c = list.where((x) => x.id == widget.consultationId).firstOrNull;
    if (c == null) return;
    _editing = c;
    _pro.text = c.professional; _spec.text = c.specialty; _loc.text = c.location; _notes.text = c.notes;
    _date = dateOnly(c.dateTime); _time = TimeOfDay.fromDateTime(c.dateTime); _status = c.status;
    _lead = leads.containsKey(c.reminderMinutes) ? c.reminderMinutes : 60;
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final when = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (_editing == null && when.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha uma data e horário futuros.')));
      return;
    }
    final c = Consultation(id: _editing?.id ?? '', patientId: ref.read(currentUidProvider)!, professional: _pro.text, specialty: _spec.text,
        location: _loc.text, notes: _notes.text, dateTime: when, status: _status, reminderMinutes: _lead);
    if (await runAction(context, () => ref.read(consultationRepositoryProvider).save(c), success: 'Consulta salva.') && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider)!;
    final list = ref.watch(consultationsProvider(uid));
    if (widget.consultationId != null && !list.hasValue) return Scaffold(appBar: AppBar(), body: const LoadingView());
    _load(list.value ?? []);
    return Scaffold(
      appBar: AppBar(title: Text(_editing == null ? 'Nova consulta' : 'Editar consulta'), actions: [
        if (_editing != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDialog(context, title: 'Excluir consulta?', message: 'Esta ação não pode ser desfeita.', confirm: 'Excluir', danger: true);
              if (!ok || !context.mounted) return;
              final done = await runAction(context, () => ref.read(consultationRepositoryProvider).delete(_editing!.id), success: 'Consulta excluída.');
              if (done && context.mounted) context.pop();
            },
          ),
      ]),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: _pro, decoration: const InputDecoration(labelText: 'Nome do profissional'), validator: (v) => Validators.required(v, 'Profissional') ?? Validators.maxLen(v, 100)),
          const SizedBox(height: 14),
          TextFormField(controller: _spec, decoration: const InputDecoration(labelText: 'Especialidade'), validator: (v) => Validators.maxLen(v, 100)),
          const SizedBox(height: 14),
          TextFormField(controller: _loc, decoration: const InputDecoration(labelText: 'Local'), validator: (v) => Validators.maxLen(v, 200)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.event), label: Text(fmtDate(_date)), onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _date = d);
            })),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.schedule), label: Text('${two(_time.hour)}:${two(_time.minute)}'), onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: _time, builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!));
              if (t != null) setState(() => _time = t);
            })),
          ]),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(initialValue: _lead, decoration: const InputDecoration(labelText: 'Lembrete'), items: [for (final e in leads.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => setState(() => _lead = v ?? _lead)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(initialValue: _status, decoration: const InputDecoration(labelText: 'Situação'), items: [for (final e in Consultation.statusLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => setState(() => _status = v ?? _status)),
          const SizedBox(height: 14),
          TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Observações'), validator: (v) => Validators.maxLen(v, 1000)),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Salvar')),
        ]),
      ),
    );
  }
}
