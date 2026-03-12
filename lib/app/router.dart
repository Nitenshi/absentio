import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/screens/welcome_screen.dart';
import '../features/onboarding/screens/semester_setup_screen.dart';
import '../features/onboarding/screens/course_setup_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/schedule/screens/schedule_screen.dart';
import '../features/course/screens/courses_screen.dart';
import '../features/course/screens/course_detail_screen.dart';
import '../features/course/screens/course_form_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/semester/screens/semester_list_screen.dart';
import '../features/semester/screens/semester_form_screen.dart';
import 'shell_scaffold.dart';

abstract final class AppRoutes {
  static const String welcome = '/welcome';
  static const String semesterSetup = '/onboarding/semester';
  static const String courseSetup = '/onboarding/courses';

  static const String dashboard = '/dashboard';
  static const String schedule = '/schedule';
  static const String courses = '/courses';
  static const String settings = '/settings';

  static const String courseDetail = '/courses/:id';
  static const String courseAdd = '/courses/add';
  static const String courseEdit = '/courses/:id/edit';
  static const String semesterList = '/settings/semesters';
  static const String semesterAdd = '/settings/semesters/add';
  static const String semesterEdit = '/settings/semesters/:id/edit';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter({required bool onboardingComplete}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation:
        onboardingComplete ? AppRoutes.dashboard : AppRoutes.welcome,
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.semesterSetup,
        builder: (context, state) => const SemesterSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.courseSetup,
        builder: (context, state) {
          final semesterId = state.extra as int;
          return CourseSetupScreen(semesterId: semesterId);
        },
      ),

      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.schedule,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ScheduleScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.courses,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CoursesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.courseAdd,
        builder: (context, state) {
          final semesterId = state.extra as int?;
          return CourseFormScreen(semesterId: semesterId);
        },
      ),
      GoRoute(
        path: AppRoutes.courseDetail,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return CourseDetailScreen(courseId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.courseEdit,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return CourseFormScreen(courseId: id);
        },
      ),

      GoRoute(
        path: AppRoutes.semesterList,
        builder: (context, state) => const SemesterListScreen(),
      ),
      GoRoute(
        path: AppRoutes.semesterAdd,
        builder: (context, state) => const SemesterFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.semesterEdit,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return SemesterFormScreen(semesterId: id);
        },
      ),
    ],
  );
}
