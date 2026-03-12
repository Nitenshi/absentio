import 'package:drift/drift.dart';

class Semesters extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  BoolColumn get hasWeekendClasses => boolean().withDefault(const Constant(true))();

  BoolColumn get uniformAttendanceReq =>
      boolean().withDefault(const Constant(false))();

  RealColumn get globalAttendanceReq =>
      real().withDefault(const Constant(0.60))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
