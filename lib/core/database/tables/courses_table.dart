import 'package:drift/drift.dart';
import 'semesters_table.dart';

class Courses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get semesterId =>
      integer().references(Semesters, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  RealColumn get attendanceRequirement =>
      real().withDefault(const Constant(0.60))();
  IntColumn get maxAbsencesOverride => integer().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0xFF399DD9))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
