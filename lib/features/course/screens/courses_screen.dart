import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semesterAsync = ref.watch(activeSemesterProvider);
    final coursesAsync = ref.watch(activeSemesterCoursesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('nav_courses')),
      ),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (courses) {
          if (courses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('course_no_courses'),
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              final courseColor = Color(course.color);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: courseColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.menu_book, color: courseColor, size: 22),
                  ),
                  title: Text(
                    course.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: semesterAsync.when(
                    data: (semester) {
                      final req = (semester != null && semester.uniformAttendanceReq)
                          ? semester.globalAttendanceReq
                          : course.attendanceRequirement;
                      return Text(
                        '${tr('course_attendance_req')}: ${(req * 100).toStringAsFixed(0)}%',
                      );
                    },
                    loading: () => Text(
                      '${tr('course_attendance_req')}: ${(course.attendanceRequirement * 100).toStringAsFixed(0)}%',
                    ),
                    error: (_, _) => Text(
                      '${tr('course_attendance_req')}: ${(course.attendanceRequirement * 100).toStringAsFixed(0)}%',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/courses/${course.id}'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: semesterAsync.when(
        data: (semester) {
          if (semester == null) return null;
          return FloatingActionButton(
            onPressed: () =>
                context.push(AppRoutes.courseAdd, extra: semester.id),
            child: const Icon(Icons.add),
          );
        },
        loading: () => null,
        error: (_, _) => null,
      ),
    );
  }
}
