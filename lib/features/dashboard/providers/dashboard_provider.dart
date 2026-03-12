import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/attendance_dao.dart';
import '../../../core/providers/database_provider.dart';

final activeSemesterProvider = StreamProvider<Semester?>((ref) {
  return ref.watch(semesterDaoProvider).watchActiveSemester();
});

final activeSemesterCoursesProvider = StreamProvider<List<Course>>((ref) {
  final semesterAsync = ref.watch(activeSemesterProvider);
  return semesterAsync.when(
    data: (semester) {
      if (semester == null) return Stream.value([]);
      return ref.watch(courseDaoProvider).watchCoursesBySemester(semester.id);
    },
    loading: () => Stream.value([]),
    error: (_, _) => Stream.value([]),
  );
});

final dashboardStatsProvider =
    FutureProvider<List<CourseAttendanceSummary>>((ref) async {
  final semester = await ref.read(semesterDaoProvider).getActiveSemester();
  if (semester == null) return [];

  final courses =
      await ref.read(courseDaoProvider).getCoursesBySemester(semester.id);
  final statsMap =
      await ref.read(attendanceDaoProvider).getStatsBySemester(semester.id);
  final courseDao = ref.read(courseDaoProvider);
  final semesterDao = ref.read(semesterDaoProvider);

  final examPeriods =
      await semesterDao.getExamPeriodsBySemester(semester.id);
  final examPeriodsData = examPeriods
      .map((p) => (
            start: p.startDate,
            end: p.endDate,
            classesHeld: p.classesHeld,
          ))
      .toList();

  final result = <CourseAttendanceSummary>[];

  for (final course in courses) {
    final schedules = await courseDao.getSchedulesByCourse(course.id);
    final scheduleDays = schedules.map((s) => s.dayOfWeek).toList();
    final totalSessions = AppConstants.countTotalSessions(
      semesterStart: semester.startDate,
      semesterEnd: semester.endDate,
      scheduleDays: scheduleDays,
      examPeriods: examPeriodsData,
      hasWeekendClasses: semester.hasWeekendClasses,
    );
    final req = semester.uniformAttendanceReq
        ? semester.globalAttendanceReq
        : course.attendanceRequirement;
    final maxAbsences = (totalSessions * (1.0 - req)).floor();

    final stats = statsMap[course.id] ?? AttendanceStats();
    final remaining = maxAbsences - stats.absent;
    final isAtRisk = remaining <= AppConstants.warningAbsoluteThreshold ||
        (maxAbsences > 0 &&
            remaining / maxAbsences <= AppConstants.warningPercentThreshold);
    final isOverLimit = remaining < 0;

    result.add(CourseAttendanceSummary(
      course: course,
      totalSessions: totalSessions,
      absent: stats.absent,
      maxAbsences: maxAbsences,
      remainingAbsences: remaining,
      isAtRisk: isAtRisk,
      isOverLimit: isOverLimit,
    ));
  }

  return result;
});

class CourseAttendanceSummary {
  final Course course;
  final int totalSessions;
  final int absent;
  final int maxAbsences;
  final int remainingAbsences;
  final bool isAtRisk;
  final bool isOverLimit;

  const CourseAttendanceSummary({
    required this.course,
    required this.totalSessions,
    required this.absent,
    required this.maxAbsences,
    required this.remainingAbsences,
    required this.isAtRisk,
    required this.isOverLimit,
  });

  double get attendanceRate =>
      totalSessions > 0 ? (totalSessions - absent) / totalSessions : 0.0;
}
