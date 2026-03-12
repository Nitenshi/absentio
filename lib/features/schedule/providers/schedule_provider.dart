import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/daos/course_dao.dart';
import '../../../core/providers/database_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

final weeklyScheduleProvider =
    StreamProvider<List<ScheduleWithCourse>>((ref) {
  final semesterAsync = ref.watch(activeSemesterProvider);
  return semesterAsync.when(
    data: (semester) {
      if (semester == null) return Stream.value([]);
      return ref.watch(courseDaoProvider).watchWeeklySchedule(semester.id);
    },
    loading: () => Stream.value([]),
    error: (_, _) => Stream.value([]),
  );
});
