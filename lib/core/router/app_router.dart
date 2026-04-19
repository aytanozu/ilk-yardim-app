import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/aed/ui/report_aed_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/debrief/models/debrief_entry.dart';
import '../../features/debrief/ui/debrief_check_in_screen.dart';
import '../../features/debrief/ui/debrief_checklist_screen.dart';
import '../../features/debrief/ui/debrief_list_screen.dart';
import '../../features/debrief/ui/debrief_resources_screen.dart';
import '../../features/intervention/ui/intervention_report_screen.dart';
import '../../features/auth/ui/not_certified_screen.dart';
import '../../features/auth/ui/otp_verify_screen.dart';
import '../../features/auth/ui/phone_entry_screen.dart';
import '../../features/auth/ui/request_access_screen.dart';
import '../../features/emergency/ui/emergency_detail_screen.dart';
import '../../features/emergency/ui/emergency_map_screen.dart';
import '../../features/feed/ui/create_post_screen.dart';
import '../../features/feed/ui/social_feed_screen.dart';
import '../../features/onboarding/ui/consent_screen.dart';
import '../../features/onboarding/ui/splash_screen.dart';
import '../../features/profile/ui/profile_screen.dart';
import '../../features/quiz/ui/quiz_screen.dart';
import '../../features/settings/ui/legal_viewer_screen.dart';
import '../../features/settings/ui/privacy_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/training/ui/training_category_screen.dart';
import '../../features/training/ui/training_center_screen.dart';
import '../../features/training/ui/training_detail_screen.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'navigator_keys.dart';

class AppRouter {
  AppRouter._();

  static GoRouter build(AuthProvider auth) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: auth,
      redirect: (context, state) {
        final stage = auth.stage;
        final path = state.matchedLocation;

        // Consent screen is a hard stop — never auto-redirect away from it.
        if (path == '/consent') return null;
        // Legal viewers are readable from anywhere (e.g. consent screen
        // tapping "Aydınlatma Metni") regardless of auth stage.
        if (path.startsWith('/legal/')) return null;
        // Emergency detail is a deep-link destination — allow even when
        // stage is still resolving, as long as we're authenticated.
        if (path.startsWith('/emergency/') &&
            stage == AuthStage.authenticated) {
          return null;
        }

        if (stage == AuthStage.unknown) {
          return path == '/splash' ? null : '/splash';
        }
        if (stage == AuthStage.notCertified) {
          // Allow the user to navigate from /auth/not-certified to the
          // self-registration request form without being bounced back.
          if (path == '/auth/request-access') return null;
          return '/auth/not-certified';
        }
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
              context.go('/auth/phone');
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
        GoRoute(
          path: '/auth/request-access',
          builder: (_, __) => const RequestAccessScreen(),
        ),
        // Full-screen emergency detail — opened from push tap / deep link.
        GoRoute(
          path: '/emergency/:id',
          builder: (context, state) => EmergencyDetailScreen(
            emergencyId: state.pathParameters['id']!,
          ),
        ),
        StatefulShellRoute.indexedStack(
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
        GoRoute(
          path: '/feed/new',
          builder: (_, __) => const CreatePostScreen(),
        ),
        GoRoute(
          path: '/training/item/:id',
          builder: (context, state) =>
              TrainingDetailScreen(itemId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/training/category/:key',
          builder: (context, state) =>
              TrainingCategoryScreen(categoryKey: state.pathParameters['key']!),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/privacy',
          builder: (_, __) => const PrivacyScreen(),
        ),
        GoRoute(
          path: '/legal/:docKey',
          builder: (context, state) => LegalViewerScreen(
            docKey: state.pathParameters['docKey']!,
          ),
        ),
        GoRoute(
          path: '/aed/report',
          builder: (_, __) => const ReportAedScreen(),
        ),
        GoRoute(
          path: '/intervention/:id',
          builder: (context, state) => InterventionReportScreen(
            emergencyId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/debriefs',
          builder: (_, __) => const DebriefListScreen(),
        ),
        GoRoute(
          path: '/debrief/:id/check-in',
          builder: (context, state) => DebriefCheckInScreen(
            emergencyId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/debrief/:id/checklist',
          builder: (context, state) {
            final extra = (state.extra as Map?) ?? const {};
            final mood = extra['mood'] as DebriefMood? ?? DebriefMood.ok;
            return DebriefChecklistScreen(
              emergencyId: state.pathParameters['id']!,
              mood: mood,
            );
          },
        ),
        GoRoute(
          path: '/debrief/:id/resources',
          builder: (context, state) {
            final extra = (state.extra as Map?) ?? const {};
            return DebriefResourcesScreen(
              emergencyId: state.pathParameters['id']!,
              mood: extra['mood'] as DebriefMood? ?? DebriefMood.ok,
              wentWell: extra['wentWell'] as String?,
              wasHard: extra['wasHard'] as String?,
              nextTime: extra['nextTime'] as String?,
              selfRating: extra['selfRating'] as int?,
            );
          },
        ),
      ],
    );
  }
}
