import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final int courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  late Future<List<Object?>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = Future.wait([
      ref.read(courseDaoProvider).getCourseById(widget.courseId),
      ref.read(courseDaoProvider).getSchedulesByCourse(widget.courseId),
      ref.read(attendanceDaoProvider).getRecordsByCourse(widget.courseId),
      ref.read(semesterDaoProvider).getActiveSemester(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final course = snapshot.data![0] as Course;
        final schedules = snapshot.data![1] as List<CourseSchedule>;
        final records = snapshot.data![2] as List<AttendanceRecord>;
        final semester = snapshot.data![3] as Semester?;

        return _CourseDetailBody(
          course: course,
          schedules: schedules,
          records: records,
          semester: semester,
          onRecordDeleted: () {
            setState(() => _loadData());
            ref.invalidate(dashboardStatsProvider);
          },
        );
      },
    );
  }
}

class _CourseDetailBody extends ConsumerWidget {
  final Course course;
  final List<CourseSchedule> schedules;
  final List<AttendanceRecord> records;
  final Semester? semester;
  final VoidCallback onRecordDeleted;

  const _CourseDetailBody({
    required this.course,
    required this.schedules,
    required this.records,
    required this.semester,
    required this.onRecordDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final courseColor = Color(course.color);

    return FutureBuilder<int>(
      future: _computeTotalSessions(ref),
      builder: (context, sessSnap) {
        final totalSessions = sessSnap.data ?? 0;
        final req = (semester != null && semester!.uniformAttendanceReq)
            ? semester!.globalAttendanceReq
            : course.attendanceRequirement;
        final maxAbsences = (totalSessions * (1.0 - req)).floor();

        final absent = records.length;
        final remaining = maxAbsences - absent;

        const dayKeys = [
          'days_mon', 'days_tue', 'days_wed', 'days_thu',
          'days_fri', 'days_sat', 'days_sun',
        ];

        final attendanceRate = totalSessions > 0
            ? (totalSessions - absent) / totalSessions * 100
            : 0.0;

        return Scaffold(
          appBar: AppBar(
            title: Text(course.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => context.push('/courses/${course.id}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      courseColor,
                      courseColor.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '${attendanceRate.toStringAsFixed(1)}%',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('attendance_rate'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  _StatTile(
                    title: tr('attendance_total_sessions'),
                    value: '$totalSessions',
                    color: theme.colorScheme.primary,
                    theme: theme,
                  ),
                  _StatTile(
                    title: tr('attendance_absent_count'),
                    value: '$absent',
                    color: AppColors.absent,
                    theme: theme,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatTile(
                    title: tr('attendance_remaining'),
                    value: '$remaining',
                    color: remaining <= AppConstants.warningAbsoluteThreshold
                        ? AppColors.warning
                        : AppColors.attended,
                    theme: theme,
                  ),
                  _StatTile(
                    title: 'Max ${tr('attendance_absent_count')}',
                    value: '$maxAbsences',
                    color: theme.colorScheme.outline,
                    theme: theme,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                tr('course_schedule'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...schedules.map((s) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.schedule, size: 20),
                    title: Text(
                      '${tr(dayKeys[s.dayOfWeek - 1])}  ${s.startTime} - ${s.endTime}',
                    ),
                  )),
              const SizedBox(height: 24),

              Text(
                tr('attendance_history'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (records.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr('common_no_data'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...records.map((r) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.circle, size: 12,
                        color: AppColors.absent),
                    title: Text(
                      '${r.date.day.toString().padLeft(2, '0')}/${r.date.month.toString().padLeft(2, '0')}/${r.date.year}',
                    ),
                    subtitle: r.note != null && r.note!.isNotEmpty
                        ? Text(r.note!)
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.absent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tr('attendance_absent'),
                            style: const TextStyle(
                              color: AppColors.absent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _confirmDeleteRecord(context, ref, r),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Future<int> _computeTotalSessions(WidgetRef ref) async {
    if (semester == null) return 0;
    final examPeriods =
        await ref.read(semesterDaoProvider).getExamPeriodsBySemester(
              semester!.id,
            );
    final scheduleDays = schedules.map((s) => s.dayOfWeek).toList();
    return AppConstants.countTotalSessions(
      semesterStart: semester!.startDate,
      semesterEnd: semester!.endDate,
      scheduleDays: scheduleDays,
      examPeriods: examPeriods
          .map((p) => (
                start: p.startDate,
                end: p.endDate,
                classesHeld: p.classesHeld,
              ))
          .toList(),
      hasWeekendClasses: semester!.hasWeekendClasses,
    );
  }

  void _confirmDeleteRecord(BuildContext context, WidgetRef ref, AttendanceRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('attendance_remove_absent')),
        content: Text(tr('attendance_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common_cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(attendanceDaoProvider).deleteRecord(record.id);
              if (context.mounted) onRecordDeleted();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(tr('common_delete')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('course_delete')),
        content: Text(tr('course_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common_cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(courseDaoProvider).deleteCourse(course.id);
              if (context.mounted) context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(tr('common_delete')),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final ThemeData theme;

  const _StatTile({
    required this.title,
    required this.value,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
