import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static Future<void> init() async {
    // App Check: Play Integrity em produção; provedor debug em desenvolvimento.
    await FirebaseAppCheck.instance
        .activate(providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider());

    // Cache offline do Firestore (fila de escritas pendentes).
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);

    // Analytics DESLIGADO até o usuário consentir (Configurações > Privacidade).
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);

    // Crashlytics: relatórios de falha (não incluir dados pessoais em mensagens de erro).
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  static Future<void> applyAnalyticsConsent(bool granted) =>
      FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(granted);
}
