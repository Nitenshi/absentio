import 'package:drift/drift.dart';
import 'semesters_table.dart';

class ExamPeriods extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get semesterId =>
      integer().references(Semesters, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().nullable().withLength(max: 100)();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get classesHeld => boolean().withDefault(const Constant(false))();
}
