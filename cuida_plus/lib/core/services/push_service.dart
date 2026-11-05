import 'dart:convert';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../firebase_options.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Mensagens com bloco "notification" são exibidas pelo sistema com o app em segundo plano.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Registro do token FCM. O disparo das notificações é feito pelas Cloud Functions.
class PushService {
  static String? _registeredUid;
  static String? _lastToken;

  static String _docId(String uid, String token) => '${uid}_${sha256.convert(utf8.encode(token))}';

  static Future<void> registerForUser(String uid) async {
    if (_registeredUid == uid) return;
    _registeredUid = uid;
    try {
      final fm = FirebaseMessaging.instance;
      final settings = await fm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await fm.getToken();
      if (token != null) await _save(uid, token);
      fm.onTokenRefresh.listen((t) => _save(uid, t));
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) NotificationService.instance.showNow(n.title ?? 'Cuida+', n.body ?? '');
      });
    } catch (_) {
      _registeredUid = null; // tenta novamente no próximo evento
    }
  }

  static Future<void> _save(String uid, String token) async {
    _lastToken = token;
    await FirebaseFirestore.instance.collection('device_tokens').doc(_docId(uid, token)).set({
      'uid': uid,
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Chamar ANTES de sair da conta, para o aparelho não receber notificações do usuário anterior.
  static Future<void> unregister(String uid) async {
    try {
      final token = _lastToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('device_tokens').doc(_docId(uid, token)).delete();
      }
    } catch (_) {}
    _registeredUid = null;
  }
}
