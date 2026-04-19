import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../router/navigator_keys.dart';

/// Handles FCM registration, token persistence, topic subscriptions,
/// foreground local notifications for critical alerts, and deep-linking
/// on notification tap (cold start, background, foreground).
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
        provisional: false,
      );

      await _initLocalNotifications();

      // Foreground: show local notif (critical channel with fullScreenIntent).
      FirebaseMessaging.onMessage.listen(_handleForeground);
      // Background → user taps system notif → app comes to fg with message.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
      // Killed → user taps notif to launch; message arrives here.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        // Delay briefly so router is ready after first frame.
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          _handleTap(initial);
        });
      }

      await _registerToken();
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    if (!kIsWeb && Platform.isAndroid) {
      final android =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Ask for notification permission (Android 13+).
      await android?.requestNotificationsPermission();
      // Ask for full-screen intent (Android 14+ — required for lock-screen wake).
      await android?.requestFullScreenIntentPermission();
      // Ask for exact alarm permission (used by scheduler in FLN 18+).
      await android?.requestExactAlarmsPermission();

      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'critical_alert',
          'Kritik Acil Çağrı',
          description: 'Hayati tehlike çağrıları — tam ekran uyarı',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'new_call',
          'Yeni Çağrı',
          description: 'Bölgenizde yeni çağrı',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );
    }
  }

  void _handleForeground(RemoteMessage message) {
    final id = message.data['emergencyId'] as String?;
    final isCritical = message.data['severity'] == 'critical';
    final channel = isCritical ? 'critical_alert' : 'new_call';
    final title = message.notification?.title ??
        (isCritical ? 'ACİL ÇAĞRI' : 'Yeni Çağrı');
    final body = message.notification?.body ?? 'Yakınınızda yeni bir vaka';

    // Critical: skip local notif and deep-link directly — we want to
    // preempt whatever screen the user is on.
    if (isCritical && id != null) {
      _navigateToEmergency(id);
      return;
    }

    _local.show(
      message.messageId.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel == 'critical_alert' ? 'Kritik Acil Çağrı' : 'Yeni Çağrı',
          importance:
              isCritical ? Importance.max : Importance.high,
          priority: Priority.high,
          fullScreenIntent: isCritical,
          playSound: true,
          enableVibration: true,
          ticker: 'Yeni acil çağrı',
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: isCritical
              ? InterruptionLevel.critical
              : InterruptionLevel.timeSensitive,
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: id,
    );
  }

  void _handleTap(RemoteMessage message) {
    final id = message.data['emergencyId'] as String?;
    if (id != null) _navigateToEmergency(id);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final id = response.payload;
    if (id != null && id.isNotEmpty) _navigateToEmergency(id);
  }

  void _navigateToEmergency(String id) {
    // Use rootNavigatorKey's context so we can route even when the call
    // originates outside the widget tree (bg handler, initial message).
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    ctx.go('/emergency/$id');
  }

  Future<void> _registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
  }

  /// Called by auth provider once user is authenticated so the token that
  /// was fetched pre-auth gets attached to their profile.
  Future<void> registerForCurrentUser() async {
    try {
      await _registerToken();
    } catch (e) {
      debugPrint('registerForCurrentUser: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  Future<void> subscribeRegion({
    required String city,
    required String district,
  }) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('tr');
      await FirebaseMessaging.instance.subscribeToTopic('tr_$city');
      await FirebaseMessaging.instance
          .subscribeToTopic('tr_${city}_$district');
    } catch (e) {
      debugPrint('subscribeRegion: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Lightweight — the OS already shows the system notification on bg push.
  // No UI navigation possible here (no Flutter engine running).
  debugPrint('bg push id=${message.data["emergencyId"]}');
}

/// Call from main() before runApp to register the bg handler.
void registerBackgroundMessageHandler() {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}
