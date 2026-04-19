import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Set at build time via `flutter run --dart-define=USE_EMULATOR=true`.
const bool kUseFirebaseEmulator =
    bool.fromEnvironment('USE_EMULATOR', defaultValue: false);

/// Rewires Firebase SDKs to the local emulator suite. Android emulator
/// maps the host machine's loopback to 10.0.2.2; everything else uses
/// 127.0.0.1. Called once from main.dart right after FirebaseBootstrap
/// if [kUseFirebaseEmulator] is true.
Future<void> configureFirebaseEmulators() async {
  if (!kUseFirebaseEmulator) return;
  final host = _emulatorHost();
  debugPrint('[emulator] wiring Firebase SDKs to $host');

  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFunctions.instanceFor(region: 'europe-west3')
      .useFunctionsEmulator(host, 5001);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
}

String _emulatorHost() {
  if (kIsWeb) return '127.0.0.1';
  try {
    if (Platform.isAndroid) return '10.0.2.2';
  } catch (_) {
    // Platform not available (web fallback already handled above).
  }
  return '127.0.0.1';
}
