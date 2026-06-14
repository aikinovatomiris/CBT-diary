import 'package:go_router/go_router.dart';

import '../models/diary_entry_model.dart';
import '../screens/admin_screens/admin_dashboard_screen.dart';
import '../screens/admin_screens/admin_pending_therapists_screen.dart';
import '../screens/admin_screens/admin_therapist_detail_screen.dart';
import '../screens/user_screens/analytics_screen.dart';
import '../screens/user_screens/assistant_settings_screen.dart';
import '../screens/authorization_screens/change_password_screen.dart';
import '../screens/user_screens/chat_screen.dart';
import '../screens/conversation_screens/conversation_detail_screen.dart';
import '../screens/conversation_screens/conversations_list_screen.dart';
import '../screens/user_screens/diary_detail_screen.dart';
import '../screens/user_screens/diary_edit_screen.dart';
import '../screens/user_screens/diary_list_screen.dart';
import '../screens/user_screens/export_preview_screen.dart';
import '../screens/user_screens/home_screen.dart';
import '../screens/authorization_screens/login_screen.dart';
import '../screens/authorization_screens/onboarding_screen.dart';
import '../screens/user_screens/practice_detail_screen.dart';
import '../screens/user_screens/practices_screen.dart';
import '../screens/authorization_screens/profile_screen.dart';
import '../screens/authorization_screens/register_screen.dart';
import '../screens/conversation_screens/shared_diary_entry_screen.dart';
import '../screens/authorization_screens/splash_screen.dart';
import '../screens/user_screens/therapist_catalog_screen.dart';
import '../screens/therapist_screens/therapist_detail_screen.dart';
import '../screens/therapist_screens/therapist_profile_screen.dart';
import '../screens/therapist_screens/therapist_register_screen.dart';
import '../screens/therapist_screens/therapist_home_screen.dart';
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
          builder: (context, state) => const TherapistHomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.therapistCard,
          builder: (context, state) => const TherapistProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.therapistMessages,
          builder: (context, state) => const ConversationsListScreen(),
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
      path: AppRoutes.conversations,
      builder: (context, state) => const ConversationsListScreen(),
    ),
    GoRoute(
      path: AppRoutes.conversationDetail,
      builder: (context, state) {
        final id = state.pathParameters['id'];

        return ConversationDetailScreen(
          conversationId: id,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.sharedDiaryEntry,
      builder: (context, state) {
        final entry = state.extra;

        return SharedDiaryEntryScreen(
          entry: entry is DiaryEntryModel ? entry : null,
        );
      },
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
      path: AppRoutes.diaryEdit,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        final entry = state.extra;

        return DiaryEditScreen(
          entryId: id,
          initialEntry: entry is DiaryEntryModel ? entry : null,
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
