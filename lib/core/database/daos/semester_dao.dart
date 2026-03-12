import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/semesters_table.dart';
import '../tables/exam_periods_table.dart';

part 'semester_dao.g.dart';

@DriftAccessor(tables: [Semesters, ExamPeriods])
class SemesterDao extends DatabaseAccessor<AppDatabase>
    with _$SemesterDaoMixin {
  SemesterDao(super.db);

  Future<List<Semester>> getAllSemesters() =>
      (select(semesters)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<Semester?> getActiveSemester() async {
    final results = await (select(semesters)
          ..where((t) => t.isActive.equals(true))
          ..limit(1))
        .get();
    return results.firstOrNull;
  }

  Stream<Semester?> watchActiveSemester() {
    return (select(semesters)
          ..where((t) => t.isActive.equals(true))
          ..limit(1))
        .watch()
        .map((rows) => rows.firstOrNull);
  }

  Future<Semester> getSemesterById(int id) =>
      (select(semesters)..where((t) => t.id.equals(id))).getSingle();

  Future<int> insertSemester(SemestersCompanion entry) =>
      into(semesters).insert(entry);

  Future<bool> updateSemester(Semester entry) =>
      update(semesters).replace(entry);

  Future<int> deleteSemester(int id) =>
      (delete(semesters)..where((t) => t.id.equals(id))).go();

  Future<void> setActiveSemester(int id) async {
    await transaction(() async {
      await (update(semesters)
            ..where((t) => t.isActive.equals(true)))
          .write(const SemestersCompanion(isActive: Value(false)));
      await (update(semesters)
            ..where((t) => t.id.equals(id)))
          .write(const SemestersCompanion(isActive: Value(true)));
    });
  }

  Future<List<ExamPeriod>> getExamPeriodsBySemester(int semesterId) =>
      (select(examPeriods)
            ..where((t) => t.semesterId.equals(semesterId))
            ..orderBy([(t) => OrderingTerm.asc(t.startDate)]))
          .get();

  Future<int> insertExamPeriod(ExamPeriodsCompanion entry) =>
      into(examPeriods).insert(entry);

  Future<void> deleteExamPeriodsBySemester(int semesterId) =>
      (delete(examPeriods)..where((t) => t.semesterId.equals(semesterId)))
          .go();
}
