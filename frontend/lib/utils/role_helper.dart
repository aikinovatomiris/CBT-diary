import '../navigation/app_routes.dart';

enum UserRole {
  user,
  therapist,
  admin,
}

class RoleHelper {
  RoleHelper._();

  static UserRole parse(String? role) {
    final normalizedRole = role?.trim().toLowerCase();

    if (normalizedRole == 'therapist') {
      return UserRole.therapist;
    }

    if (normalizedRole == 'admin') {
      return UserRole.admin;
    }

    return UserRole.user;
  }

  static String normalize(String? role) {
    return parse(role).name;
  }

  static bool isUser(String? role) {
    return parse(role) == UserRole.user;
  }

  static bool isTherapist(String? role) {
    return parse(role) == UserRole.therapist;
  }

  static bool isAdmin(String? role) {
    return parse(role) == UserRole.admin;
  }

  static String startRouteForRole(String? role) {
    switch (parse(role)) {
      case UserRole.user:
        return AppRoutes.home;
      case UserRole.therapist:
        return AppRoutes.therapistHome;
      case UserRole.admin:
        return AppRoutes.adminHome;
    }
  }

  static String roleTitle(String? role) {
    switch (parse(role)) {
      case UserRole.user:
        return 'Пользователь';
      case UserRole.therapist:
        return 'Терапевт';
      case UserRole.admin:
        return 'Администратор';
    }
  }
}