import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/attendance_records_table.dart';
import '../tables/course_schedules_table.dart';
import '../tables/courses_table.dart';

part 'attendance_dao.g.dart';

@DriftAccessor(tables: [AttendanceRecords, CourseSchedules, Courses])
class AttendanceDao extends DatabaseAccessor<AppDatabase>
    with _$AttendanceDaoMixin {
  AttendanceDao(super.db);

  Future<List<AttendanceRecord>> getRecordsByCourse(int courseId) =>
      (select(attendanceRecords)
            ..where((t) => t.courseId.equals(courseId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<int> countAbsencesByCourse(int courseId) async {
    final absenceCount = attendanceRecords.id.count();
    final query = selectOnly(attendanceRecords)
      ..where(attendanceRecords.courseId.equals(courseId))
      ..where(attendanceRecords.status.equals(1))
      ..addColumns([absenceCount]);

    final row = await query.getSingleOrNull();
    return row?.read(absenceCount) ?? 0;
  }

  Future<bool> existsByScheduleAndDate(int courseScheduleId, DateTime date) async {
    final query = select(attendanceRecords)
      ..where((t) => t.courseScheduleId.equals(courseScheduleId) & t.date.equals(date))
      ..limit(1);
    final rows = await query.get();
    return rows.isNotEmpty;
  }

  Future<void> upsertAttendance(AttendanceRecordsCompanion entry) =>
      into(attendanceRecords).insertOnConflictUpdate(entry);

  Future<int> deleteRecord(int id) =>
      (delete(attendanceRecords)..where((t) => t.id.equals(id))).go();

  Future<Map<int, AttendanceStats>> getStatsBySemester(int semesterId) async {
    final query = select(attendanceRecords).join([
      innerJoin(courses, courses.id.equalsExp(attendanceRecords.courseId)),
    ])
      ..where(courses.semesterId.equals(semesterId));

    final rows = await query.get();
    final stats = <int, AttendanceStats>{};

    for (final row in rows) {
      final course = row.readTable(courses);
      final entry = stats.putIfAbsent(
        course.id,
        () => AttendanceStats(),
      );
      entry.absent++;
    }
    return stats;
  }
}

class AttendanceStats {
  int absent = 0;
}
