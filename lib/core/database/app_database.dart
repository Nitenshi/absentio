import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/semesters_table.dart';
import 'tables/courses_table.dart';
import 'tables/course_schedules_table.dart';
import 'tables/attendance_records_table.dart';
import 'tables/exam_periods_table.dart';
import 'daos/semester_dao.dart';
import 'daos/course_dao.dart';
import 'daos/attendance_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Semesters, Courses, CourseSchedules, AttendanceRecords, ExamPeriods],
  daos: [SemesterDao, CourseDao, AttendanceDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static AppDatabase? _instance;

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Preserve user data across app updates.
          // Add explicit migration steps here when schema changes.
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'absentio.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
