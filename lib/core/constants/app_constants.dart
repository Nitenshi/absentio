abstract final class AppConstants {
  static const String appName = 'Absentio';
  static const String dbName = 'absentio.sqlite';

  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLocale = 'locale';
  static const String keySkippedVersion = 'skipped_version';

  static const String githubOwner = 'nitenshi';
  static const String githubRepo = 'absentio';

  static const double defaultAttendanceRequirement = 0.60;

  static const int statusAbsent = 1;

  static const int warningAbsoluteThreshold = 2;
  static const double warningPercentThreshold = 0.25;

  static int totalDays(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return e.difference(s).inDays + 1;
  }

  static int countWeekdays(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    final days = e.difference(s).inDays + 1;
    if (days <= 0) return 0;
    final fullWeeks = days ~/ 7;
    final remaining = days % 7;
    int count = fullWeeks * 5;
    for (int i = 0; i < remaining; i++) {
      final wd = ((s.weekday - 1 + i) % 7) + 1;
      if (wd <= 5) count++;
    }
    return count;
  }

  static ({int weeks, int days}) effectiveDuration({
    required DateTime semesterStart,
    required DateTime semesterEnd,
    required List<({DateTime start, DateTime end, bool classesHeld})> examPeriods,
    bool hasWeekendClasses = true,
  }) {
    final int Function(DateTime, DateTime) countFn =
        hasWeekendClasses ? totalDays : countWeekdays;
    final total = countFn(semesterStart, semesterEnd);
    int examDayCount = 0;
    for (final p in examPeriods) {
      if (!p.classesHeld) {
        examDayCount += countFn(p.start, p.end);
      }
    }
    final effective = (total - examDayCount).clamp(0, total);
    return (weeks: effective ~/ 7, days: effective % 7);
  }

  static ({int weeks, int days}) totalDuration(DateTime start, DateTime end) {
    final d = totalDays(start, end);
    return (weeks: d ~/ 7, days: d % 7);
  }

  static ({int weeks, int days}) examDuration(
    List<({DateTime start, DateTime end, bool classesHeld})> examPeriods, {
    bool hasWeekendClasses = true,
  }) {
    final int Function(DateTime, DateTime) countFn =
        hasWeekendClasses ? totalDays : countWeekdays;
    int d = 0;
    for (final p in examPeriods) {
      if (!p.classesHeld) {
        d += countFn(p.start, p.end);
      }
    }
    return (weeks: d ~/ 7, days: d % 7);
  }

  static int countDayOccurrences(DateTime start, DateTime end, int dayOfWeek) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    final days = e.difference(s).inDays + 1;
    if (days <= 0) return 0;
    final fullWeeks = days ~/ 7;
    final remaining = days % 7;
    int count = fullWeeks;
    for (int i = 0; i < remaining; i++) {
      final wd = ((s.weekday - 1 + i) % 7) + 1;
      if (wd == dayOfWeek) count++;
    }
    return count;
  }

  static int countTotalSessions({
    required DateTime semesterStart,
    required DateTime semesterEnd,
    required List<int> scheduleDays,
    required List<({DateTime start, DateTime end, bool classesHeld})> examPeriods,
    bool hasWeekendClasses = true,
  }) {
    int total = 0;
    for (final day in scheduleDays) {
      if (!hasWeekendClasses && (day == 6 || day == 7)) continue;
      total += countDayOccurrences(semesterStart, semesterEnd, day);
      for (final p in examPeriods) {
        if (!p.classesHeld) {
          total -= countDayOccurrences(p.start, p.end, day);
        }
      }
    }
    return total.clamp(0, 10000);
  }

  static String formatWeeksDays(
    ({int weeks, int days}) wd,
    String unitWeeks,
    String unitDays,
  ) {
    if (wd.weeks > 0 && wd.days > 0) return '${wd.weeks} $unitWeeks ${wd.days} $unitDays';
    if (wd.weeks > 0) return '${wd.weeks} $unitWeeks';
    return '${wd.days} $unitDays';
  }
}
