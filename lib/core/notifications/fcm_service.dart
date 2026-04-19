import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles FCM registration, token persistence, topic subscriptions, and
/// foreground local notifications for critical alerts.
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

      // Android 13+ POST_NOTIFICATIONS runtime prompt handled elsewhere via
      // permission_handler.
      await _initLocalNotifications();

      FirebaseMessaging.onMessage.listen(_handleForeground);
      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

      await _registerToken();
      FirebaseMessaging.instance.onTokenRefresh.listen((t) => _saveToken(t));
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
    );

    // Channels
    if (!kIsWeb && Platform.isAndroid) {
      final android =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'critical_alert',
          'Kritik Acil Çağrı',
          description: 'Hayati tehlike çağrıları',
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
    final notif = message.notification;
    if (notif == null) return;

    final isCritical = message.data['severity'] == 'critical';
    final channel = isCritical ? 'critical_alert' : 'new_call';

    _local.show(
      message.messageId.hashCode,
      notif.title,
      notif.body,
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
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel:
              isCritical ? InterruptionLevel.critical : InterruptionLevel.timeSensitive,
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['emergencyId'] as String?,
    );
  }

  Future<void> _registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
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
Future<void> _backgroundHandler(RemoteMessage message) async {
  debugPrint('bg message: ${message.messageId}');
}
