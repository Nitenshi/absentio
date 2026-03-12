import 'package:drift/drift.dart' hide Column;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/course_dao.dart';
import '../../../core/providers/database_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../providers/schedule_provider.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _today = DateTime.now().weekday; // 1=Mon..7=Sun
  NavigatorState? _sheetNavigator;

  static const _dayKeys = [
    'days_monday',
    'days_tuesday',
    'days_wednesday',
    'days_thursday',
    'days_friday',
    'days_saturday',
    'days_sunday',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: (_today - 1).clamp(0, 6),
    );
  }

  @override
  void deactivate() {
    if (_sheetNavigator != null) {
      _sheetNavigator!.pop();
      _sheetNavigator = null;
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheduleAsync = ref.watch(weeklyScheduleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('nav_schedule')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: List.generate(7, (i) {
            final isToday = i == _today - 1;
            return Tab(
              child: Text(
                tr(_dayKeys[i]),
                style: isToday
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null,
              ),
            );
          }),
        ),
      ),
      body: scheduleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (allSchedules) {
          if (allSchedules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('schedule_empty'),
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: List.generate(7, (dayIndex) {
              final daySchedules = allSchedules
                  .where((s) => s.schedule.dayOfWeek == dayIndex + 1)
                  .toList();

              if (daySchedules.isEmpty) {
                return Center(
                  child: Text(
                    tr('schedule_no_classes'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: daySchedules.length,
                itemBuilder: (context, index) {
                  final item = daySchedules[index];
                  final courseColor = Color(item.course.color);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showAttendanceDialog(context, item),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 50,
                              decoration: BoxDecoration(
                                color: courseColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.schedule.startTime,
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  item.schedule.endTime,
                                  style:
                                      theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Text(
                                item.course.name,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            const Icon(Icons.touch_app_outlined, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          );
        },
      ),
    );
  }

  void _showAttendanceDialog(BuildContext context, ScheduleWithCourse item) {
    final semesterAsync = ref.read(activeSemesterProvider);
    final semester = semesterAsync.valueOrNull;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var firstDate = semester?.startDate ?? DateTime(2020);
    final lastDate = firstDate.isAfter(today) ? firstDate : today;

    final allSchedules = ref.read(weeklyScheduleProvider).valueOrNull ?? [];
    final courseDays = allSchedules
        .where((s) => s.course.id == item.course.id)
        .map((s) => s.schedule.dayOfWeek)
        .toSet();
    courseDays.add(item.schedule.dayOfWeek);

    DateTime selectedDate = today;
    while (!courseDays.contains(selectedDate.weekday)) {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
    }
    if (selectedDate.isBefore(firstDate)) {
      selectedDate = firstDate;
      while (!courseDays.contains(selectedDate.weekday)) {
        selectedDate = selectedDate.add(const Duration(days: 1));
      }
    }
    if (selectedDate.isAfter(lastDate)) {
      selectedDate = lastDate;
      while (!courseDays.contains(selectedDate.weekday)) {
        selectedDate = selectedDate.subtract(const Duration(days: 1));
      }
    }
    if (selectedDate.isBefore(firstDate)) {
      firstDate = selectedDate;
    }

    final reasonController = TextEditingController();

    _sheetNavigator = Navigator.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${item.course.name}  •  ${item.schedule.startTime}',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      selectableDayPredicate: (date) =>
                          courseDays.contains(date.weekday),
                    );
                    if (picked != null) {
                      setSheetState(() => selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: tr('attendance_select_date'),
                      suffixIcon:
                          const Icon(Icons.calendar_today, size: 20),
                    ),
                    child: Text(
                      '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: tr('attendance_reason'),
                    hintText: tr('attendance_reason'),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: () {
                    final targetItem = allSchedules.firstWhere(
                      (s) =>
                          s.course.id == item.course.id &&
                          s.schedule.dayOfWeek == selectedDate.weekday,
                      orElse: () => item,
                    );
                    Navigator.pop(ctx);
                    _markAbsent(
                      targetItem,
                      selectedDate,
                      reasonController.text.trim(),
                    );
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(tr('attendance_mark_absent')),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(ctx).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      _sheetNavigator = null;
      reasonController.dispose();
    });
  }

  Future<void> _markAbsent(
    ScheduleWithCourse item,
    DateTime date,
    String reason,
  ) async {
    final dao = ref.read(attendanceDaoProvider);

    final exists = await dao.existsByScheduleAndDate(item.schedule.id, date);
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('attendance_already_marked')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    await dao.upsertAttendance(
      AttendanceRecordsCompanion(
        courseId: Value(item.course.id),
        courseScheduleId: Value(item.schedule.id),
        date: Value(date),
        status: const Value(1),
        note: Value(reason.isEmpty ? null : reason),
      ),
    );

    ref.invalidate(weeklyScheduleProvider);
    ref.invalidate(dashboardStatsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('attendance_marked')),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}
