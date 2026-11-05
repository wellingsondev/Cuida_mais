import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id, title, body;
  final bool read;
  final DateTime? createdAt;
  const AppNotification({required this.id, required this.title, required this.body, required this.read, this.createdAt});
  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return AppNotification(id: d.id, title: m['title'] ?? '', body: m['body'] ?? '', read: m['read'] == true, createdAt: (m['createdAt'] as Timestamp?)?.toDate());
  }
}
