class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String registerTherapist =
      '/register-therapist';

  // User routes
  static const String home = '/home';
  static const String session = '/session';
  static const String chat = '/chat';
  static const String diary = '/diary';
  static const String diaryDetail = '/diary/:id';
  static const String diaryEdit = '/diary/:id/edit';
  static const String analytics = '/analytics';
  static const String practices = '/practices';
  static const String practiceDetail =
      '/practices/:id';
  static const String therapistCatalog =
      '/specialists';
  static const String therapistDetail =
      '/specialists/:id';
  static const String profile = '/profile';
  static const String assistantSettings =
      '/assistant-settings';
  static const String changePassword =
      '/change-password';
  static const String exportPreview =
      '/export-preview';

  // Conversations
  static const String conversations =
      '/conversations';
  static const String conversationDetail =
      '/conversations/:id';
  static const String sharedDiaryEntry =
      '/shared-diary-entry';

  // Notifications
  static const String notifications =
      '/notifications';

  // Therapist routes
  static const String therapistHome =
      '/therapist-home';
  static const String therapistCard =
      '/therapist-card';
  static const String therapistMessages =
      '/therapist-messages';

  // Admin routes
  static const String adminHome = '/admin';
  static const String adminTherapists =
      '/admin/therapists';
  static const String adminTherapistDetail =
      '/admin/therapists/:id';
  static const String adminStatistics =
      '/admin/statistics';
}