import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/ui/not_certified_screen.dart';
import '../../features/auth/ui/otp_verify_screen.dart';
import '../../features/auth/ui/phone_entry_screen.dart';
import '../../features/emergency/ui/emergency_map_screen.dart';
import '../../features/feed/ui/social_feed_screen.dart';
import '../../features/onboarding/ui/consent_screen.dart';
import '../../features/onboarding/ui/splash_screen.dart';
import '../../features/profile/ui/profile_screen.dart';
import '../../features/quiz/ui/quiz_screen.dart';
import '../../features/training/ui/training_center_screen.dart';
import '../../shared/widgets/app_scaffold.dart';

class AppRouter {
  AppRouter._();

  static GoRouter build(AuthProvider auth) {
    final shellKey = GlobalKey<NavigatorState>();
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: auth,
      redirect: (context, state) {
        final stage = auth.stage;
        final path = state.matchedLocation;

        // Consent screen is a hard stop — never auto-redirect away from it.
        if (path == '/consent') return null;

        if (stage == AuthStage.unknown) {
          return path == '/splash' ? null : '/splash';
        }
        if (stage == AuthStage.notCertified) return '/auth/not-certified';
        if (stage == AuthStage.awaitingCode ||
            stage == AuthStage.finalizing) {
          return '/auth/otp';
        }
        if (stage == AuthStage.phoneEntry && !path.startsWith('/auth')) {
          return '/auth/phone';
        }
        if (stage == AuthStage.authenticated &&
            (path.startsWith('/auth') || path == '/splash')) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(
          path: '/consent',
          builder: (context, __) => ConsentScreen(
            onAccepted: () {
              context.read<AuthProvider>().resetToPhoneEntry();
            },
          ),
        ),
        GoRoute(
          path: '/auth/phone',
          builder: (_, __) => const PhoneEntryScreen(),
        ),
        GoRoute(
          path: '/auth/otp',
          builder: (_, __) => const OtpVerifyScreen(),
        ),
        GoRoute(
          path: '/auth/not-certified',
          builder: (_, __) => const NotCertifiedScreen(),
        ),
        StatefulShellRoute.indexedStack(
          parentNavigatorKey: shellKey,
          builder: (context, state, shell) =>
              AppShellScaffold(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const EmergencyMapScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/training',
                builder: (_, __) => const TrainingCenterScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/feed',
                builder: (_, __) => const SocialFeedScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ]),
          ],
        ),
        GoRoute(
          path: '/quiz/:id',
          builder: (context, state) => QuizScreen(
            quizId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
  }
}
