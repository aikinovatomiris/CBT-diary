import 'package:go_router/go_router.dart';

import '../screens/admin_dashboard_screen.dart';
import '../screens/admin_pending_therapists_screen.dart';
import '../screens/admin_therapist_detail_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/assistant_settings_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/diary_detail_screen.dart';
import '../screens/diary_list_screen.dart';
import '../screens/export_preview_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/practice_detail_screen.dart';
import '../screens/practices_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/register_screen.dart';
import '../screens/role_placeholder_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/therapist_catalog_screen.dart';
import '../screens/therapist_detail_screen.dart';
import '../screens/therapist_profile_screen.dart';
import '../screens/therapist_register_screen.dart';
import 'app_routes.dart';
import 'main_scaffold.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: AppRoutes.registerTherapist,
      builder: (context, state) => const TherapistRegisterScreen(),
    ),

    ShellRoute(
      builder: (context, state, child) {
        return MainScaffold(
          currentLocation: state.uri.toString(),
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.diary,
          builder: (context, state) => const DiaryListScreen(),
        ),
        GoRoute(
          path: AppRoutes.practices,
          builder: (context, state) => const PracticesScreen(),
        ),
        GoRoute(
          path: AppRoutes.therapistCatalog,
          builder: (context, state) => const TherapistCatalogScreen(),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),

        GoRoute(
          path: AppRoutes.therapistHome,
          builder: (context, state) => const RolePlaceholderScreen(
            title: 'Главная',
            description: 'Рабочий экран специалиста.',
          ),
        ),
        GoRoute(
          path: AppRoutes.therapistCard,
          builder: (context, state) => const TherapistProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.therapistMessages,
          builder: (context, state) => const RolePlaceholderScreen(
            title: 'Клиенты/Сообщения',
            description: 'Здесь будут клиенты и сообщения специалиста.',
          ),
        ),

        GoRoute(
          path: AppRoutes.adminHome,
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminTherapists,
          builder: (context, state) => const AdminPendingTherapistsScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminStatistics,
          builder: (context, state) => const AdminDashboardScreen(),
        ),
      ],
    ),

    GoRoute(
      path: AppRoutes.chat,
      builder: (context, state) {
        final sessionId = state.uri.queryParameters['session_id'];

        return ChatScreen(
          sessionId: sessionId,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.diaryDetail,
      builder: (context, state) {
        final id = state.pathParameters['id'];

        return DiaryDetailScreen(
          entryId: id,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.analytics,
      builder: (context, state) => const AnalyticsScreen(),
    ),
    GoRoute(
      path: AppRoutes.assistantSettings,
      builder: (context, state) => const AssistantSettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.changePassword,
      builder: (context, state) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.practiceDetail,
      builder: (context, state) {
        final id = state.pathParameters['id'];

        return PracticeDetailScreen(
          practiceId: id,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.therapistDetail,
      builder: (context, state) {
        final id = state.pathParameters['id'];

        return TherapistDetailScreen(
          profileId: id,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.adminTherapistDetail,
      builder: (context, state) {
        final id = state.pathParameters['id'];

        return AdminTherapistDetailScreen(
          profileId: id,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.exportPreview,
      builder: (context, state) {
        final exportedText = state.extra;

        return ExportPreviewScreen(
          text: exportedText is String ? exportedText : '',
        );
      },
    ),
  ],
);