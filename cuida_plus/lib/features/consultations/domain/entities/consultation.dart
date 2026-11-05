import 'package:cloud_firestore/cloud_firestore.dart';

class Consultation {
  final String id, patientId, professional, specialty, location, notes;
  final DateTime dateTime;
  final String status; // scheduled | done | cancelled
  final int reminderMinutes;
  final bool pendingSync;
  const Consultation({this.id = '', required this.patientId, required this.professional, this.specialty = '', this.location = '', this.notes = '',
    required this.dateTime, this.status = 'scheduled', this.reminderMinutes = 60, this.pendingSync = false});

  static const statusLabels = {'scheduled': 'Agendada', 'done': 'Realizada', 'cancelled': 'Cancelada'};

  factory Consultation.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Consultation(id: d.id, patientId: m['patientId'], professional: m['professional'] ?? '', specialty: m['specialty'] ?? '',
        location: m['location'] ?? '', notes: m['notes'] ?? '', dateTime: (m['dateTime'] as Timestamp).toDate(),
        status: m['status'] ?? 'scheduled', reminderMinutes: m['reminderMinutes'] ?? 60, pendingSync: d.metadata.hasPendingWrites);
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId, 'professional': professional.trim(), 'specialty': specialty.trim(), 'location': location.trim(),
        'notes': notes.trim(), 'dateTime': Timestamp.fromDate(dateTime), 'status': status, 'reminderMinutes': reminderMinutes,
      };
}
