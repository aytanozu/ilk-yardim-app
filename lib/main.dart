import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/config/remote_config_service.dart';
import 'core/firebase/emulator_config.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/location/background_service_runner.dart';
import 'core/location/location_provider.dart';
import 'core/notifications/fcm_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initializeDateFormatting('tr_TR');

  final firebaseReady = await FirebaseBootstrap.init();
  if (firebaseReady) {
    // Must run BEFORE any Firestore/Auth/Functions call so the SDKs
    // latch onto the emulator addresses.
    await configureFirebaseEmulators();
    registerBackgroundMessageHandler();
    await AppRemoteConfig.instance.init();
    // Fire-and-forget — FCM registers tokens after auth.
    unawaited(FcmService.instance.init());
    // Prepare native foreground service (survives app kill).
    await BackgroundServiceRunner.instance.configure();
  }

  // Riverpod ProviderScope wraps the whole app so new code can
  // `ref.watch(xProvider)` without explicit context lookups. The legacy
  // MultiProvider inside IlkYardimApp still owns AuthProvider /
  // LocationProvider; Riverpod handles the repo DI and any new
  // observable state moving forward.
  runApp(const ProviderScope(child: IlkYardimApp()));
}

class IlkYardimApp extends StatelessWidget {
  const IlkYardimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: Builder(
        builder: (context) {
          final router = AppRouter.build(context.read<AuthProvider>());
          return MaterialApp.router(
            title: 'Klinik Nabız',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: const Locale('tr', 'TR'),
            supportedLocales: const [
              Locale('tr', 'TR'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
          );
        },
      ),
    );
  }
}
