import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/semester_dao.dart';
import '../database/daos/course_dao.dart';
import '../database/daos/attendance_dao.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final semesterDaoProvider = Provider<SemesterDao>((ref) {
  return ref.watch(databaseProvider).semesterDao;
});

final courseDaoProvider = Provider<CourseDao>((ref) {
  return ref.watch(databaseProvider).courseDao;
});

final attendanceDaoProvider = Provider<AttendanceDao>((ref) {
  return ref.watch(databaseProvider).attendanceDao;
});
