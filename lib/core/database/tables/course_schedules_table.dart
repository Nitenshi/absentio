import 'package:drift/drift.dart';
import 'courses_table.dart';

class CourseSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();

  IntColumn get dayOfWeek => integer().check(
        const CustomExpression<bool>('day_of_week BETWEEN 1 AND 7'),
      )();

  TextColumn get startTime => text().withLength(min: 5, max: 5)();
  TextColumn get endTime => text().withLength(min: 5, max: 5)();
}
