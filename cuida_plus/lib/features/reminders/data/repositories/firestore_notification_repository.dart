import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<List<AppNotification>> watch(String uid) => _db.collection('notifications').where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true).limit(50).snapshots().map((s) => s.docs.map(AppNotification.fromDoc).toList());

  @override
  Future<void> markRead(String id) => guard(() => _db.collection('notifications').doc(id).update({'read': true}), write: true);

  @override
  Future<bool> remoteEnabled(String uid) async {
    final d = await _db.collection('notification_preferences').doc(uid).get();
    return d.data()?['enabled'] != false;
  }

  @override
  Future<void> setRemoteEnabled(String uid, bool enabled) => guard(
      () => _db.collection('notification_preferences').doc(uid).set({'enabled': enabled, 'updatedAt': FieldValue.serverTimestamp()}), write: true);
}
