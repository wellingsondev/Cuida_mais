import '../entities/app_notification.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> watch(String uid);
  Future<void> markRead(String id);
  Future<bool> remoteEnabled(String uid);
  Future<void> setRemoteEnabled(String uid, bool enabled);
}
