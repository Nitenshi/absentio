import 'package:drift/drift.dart';
import 'courses_table.dart';
import 'course_schedules_table.dart';

class AttendanceRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();

  IntColumn get courseScheduleId => integer()
      .nullable()
      .references(CourseSchedules, #id, onDelete: KeyAction.setNull)();

  DateTimeColumn get date => dateTime()();

  IntColumn get status => integer().withDefault(const Constant(0))();

  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {courseId, date, courseScheduleId},
      ];
}
