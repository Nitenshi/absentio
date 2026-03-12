import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/courses_table.dart';
import '../tables/course_schedules_table.dart';

part 'course_dao.g.dart';

@DriftAccessor(tables: [Courses, CourseSchedules])
class CourseDao extends DatabaseAccessor<AppDatabase> with _$CourseDaoMixin {
  CourseDao(super.db);

  Future<List<Course>> getCoursesBySemester(int semesterId) =>
      (select(courses)
            ..where((t) => t.semesterId.equals(semesterId))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Stream<List<Course>> watchCoursesBySemester(int semesterId) =>
      (select(courses)
            ..where((t) => t.semesterId.equals(semesterId))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<Course> getCourseById(int id) =>
      (select(courses)..where((t) => t.id.equals(id))).getSingle();

  Future<int> insertCourse(CoursesCompanion entry) =>
      into(courses).insert(entry);

  Future<bool> updateCourse(Course entry) => update(courses).replace(entry);

  Future<int> deleteCourse(int id) =>
      (delete(courses)..where((t) => t.id.equals(id))).go();

  Future<List<CourseSchedule>> getSchedulesByCourse(int courseId) =>
      (select(courseSchedules)
            ..where((t) => t.courseId.equals(courseId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.dayOfWeek),
              (t) => OrderingTerm.asc(t.startTime),
            ]))
          .get();

  Future<List<ScheduleWithCourse>> getWeeklySchedule(int semesterId) async {
    final query = select(courseSchedules).join([
      innerJoin(courses, courses.id.equalsExp(courseSchedules.courseId)),
    ])
      ..where(courses.semesterId.equals(semesterId))
      ..orderBy([
        OrderingTerm.asc(courseSchedules.dayOfWeek),
        OrderingTerm.asc(courseSchedules.startTime),
      ]);

    final rows = await query.get();
    return rows.map((row) {
      return ScheduleWithCourse(
        schedule: row.readTable(courseSchedules),
        course: row.readTable(courses),
      );
    }).toList();
  }

  Stream<List<ScheduleWithCourse>> watchWeeklySchedule(int semesterId) {
    final query = select(courseSchedules).join([
      innerJoin(courses, courses.id.equalsExp(courseSchedules.courseId)),
    ])
      ..where(courses.semesterId.equals(semesterId))
      ..orderBy([
        OrderingTerm.asc(courseSchedules.dayOfWeek),
        OrderingTerm.asc(courseSchedules.startTime),
      ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ScheduleWithCourse(
          schedule: row.readTable(courseSchedules),
          course: row.readTable(courses),
        );
      }).toList();
    });
  }

  Future<int> insertSchedule(CourseSchedulesCompanion entry) =>
      into(courseSchedules).insert(entry);

  Future<bool> updateSchedule(CourseSchedule entry) =>
      update(courseSchedules).replace(entry);

  Future<int> deleteSchedule(int id) =>
      (delete(courseSchedules)..where((t) => t.id.equals(id))).go();
}

class ScheduleWithCourse {
  final CourseSchedule schedule;
  final Course course;

  const ScheduleWithCourse({
    required this.schedule,
    required this.course,
  });
}
