import 'package:drift/drift.dart' hide Column;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../settings/providers/settings_provider.dart';

class CourseSetupScreen extends ConsumerStatefulWidget {
  final int semesterId;

  const CourseSetupScreen({super.key, required this.semesterId});

  @override
  ConsumerState<CourseSetupScreen> createState() => _CourseSetupScreenState();
}

class _CourseSetupScreenState extends ConsumerState<CourseSetupScreen> {
  final List<_CourseEntry> _courses = [];
  bool _saving = false;
  bool _sameAttendanceForAll = false;
  final TextEditingController _globalReqController =
      TextEditingController(text: '60');

  @override
  void initState() {
    super.initState();
    _loadSemesterSettings();
  }

  Future<void> _loadSemesterSettings() async {
    final dao = ref.read(semesterDaoProvider);
    final semester = await dao.getSemesterById(widget.semesterId);
    if (mounted) {
      setState(() {
        _sameAttendanceForAll = semester.uniformAttendanceReq;
        _globalReqController.text =
            (semester.globalAttendanceReq * 100).toStringAsFixed(0);
      });
    }
  }

  static const _courseColors = [
    Color(0xFF399DD9), // primary
    Color(0xFF39D9B3), // teal
    Color(0xFFE53935), // red
    Color(0xFFFFA726), // orange
    Color(0xFF66BB6A), // green
    Color(0xFFAB47BC), // purple
    Color(0xFFFF7043), // deep orange
    Color(0xFF5C6BC0), // indigo
    Color(0xFF26C6DA), // cyan
    Color(0xFFEC407A), // pink
  ];

  void _addCourse() {
    setState(() {
      _courses.add(_CourseEntry(
        colorValue: _courseColors[_courses.length % _courseColors.length].toARGB32(),
      ));
    });
  }

  void _removeCourse(int index) {
    setState(() => _courses.removeAt(index));
  }

  Future<void> _finish() async {
    for (final course in _courses) {
      if (course.nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('common_required_field'))),
        );
        return;
      }
      if (course.schedules.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${course.nameController.text}: ${tr('schedule_add_slot')}',
            ),
          ),
        );
        return;
      }
    }

    final names = _courses.map((c) => c.nameController.text.trim().toLowerCase()).toList();
    if (names.toSet().length != names.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('course_duplicate_name'))),
      );
      return;
    }

    setState(() => _saving = true);

    final courseDao = ref.read(courseDaoProvider);

    for (final entry in _courses) {
      final double req;

      if (_sameAttendanceForAll) {
        req = (double.tryParse(_globalReqController.text) ?? 60) / 100;
      } else {
        req = (double.tryParse(entry.requirementController.text) ?? 60) / 100;
      }

      final courseId = await courseDao.insertCourse(
        CoursesCompanion.insert(
          semesterId: widget.semesterId,
          name: entry.nameController.text.trim(),
          attendanceRequirement: Value(req),
          color: Value(entry.colorValue),
        ),
      );

      for (final slot in entry.schedules) {
        await courseDao.insertSchedule(
          CourseSchedulesCompanion.insert(
            courseId: courseId,
            dayOfWeek: slot.dayOfWeek,
            startTime: slot.startTime,
            endTime: slot.endTime,
          ),
        );
      }
    }

    await setOnboardingComplete();

    if (mounted) {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  void dispose() {
    _globalReqController.dispose();
    for (final c in _courses) {
      c.nameController.dispose();
      c.requirementController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('course_setup_title')),
        leading: BackButton(onPressed: () => context.go(AppRoutes.welcome)),
      ),
      body: _courses.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('course_no_courses'),
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                if (_sameAttendanceForAll) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr('course_attendance_locked',
                                args: [_globalReqController.text]),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ...List.generate(_courses.length, (index) => _CourseCard(
                  entry: _courses[index],
                  index: index,
                  onRemove: () => _removeCourse(index),
                  courseColors: _courseColors,
                  onChanged: () => setState(() {}),
                  hideAttendance: _sameAttendanceForAll,
                  allCourses: _courses,
                )),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_course',
            onPressed: _addCourse,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'finish',
            onPressed: (_saving || _courses.isEmpty) ? null : _finish,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            label: Text(tr('onboarding_finish')),
          ),
        ],
      ),
    );
  }
}

class _CourseEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController requirementController =
      TextEditingController(text: '60');
  int colorValue;
  final List<_ScheduleSlot> schedules = [];

  _CourseEntry({required this.colorValue});
}

class _ScheduleSlot {
  int dayOfWeek;
  String startTime;
  String endTime;

  _ScheduleSlot({
    this.dayOfWeek = 1,
    this.startTime = '09:00',
    this.endTime = '10:00',
  });
}

class _CourseCard extends StatelessWidget {
  final _CourseEntry entry;
  final int index;
  final VoidCallback onRemove;
  final List<Color> courseColors;
  final VoidCallback onChanged;
  final bool hideAttendance;
  final List<_CourseEntry> allCourses;

  const _CourseCard({
    required this.entry,
    required this.index,
    required this.onRemove,
    required this.courseColors,
    required this.onChanged,
    required this.hideAttendance,
    required this.allCourses,
  });

  static const _dayKeys = [
    'days_mon', 'days_tue', 'days_wed', 'days_thu',
    'days_fri', 'days_sat', 'days_sun',
  ];

  ({String courseName, String dayKey})? _findConflict(int day, TimeOfDay start, TimeOfDay end) {
    final newStart = start.hour * 60 + start.minute;
    final newEnd = end.hour * 60 + end.minute;

    for (final course in allCourses) {
      for (final slot in course.schedules) {
        if (slot.dayOfWeek != day) continue;
        final parts1 = slot.startTime.split(':');
        final parts2 = slot.endTime.split(':');
        final existStart = int.parse(parts1[0]) * 60 + int.parse(parts1[1]);
        final existEnd = int.parse(parts2[0]) * 60 + int.parse(parts2[1]);
        if (newStart < existEnd && newEnd > existStart) {
          return (
            courseName: course.nameController.text.isEmpty
                ? '${tr('nav_courses')} ${allCourses.indexOf(course) + 1}'
                : course.nameController.text,
            dayKey: _dayKeys[day - 1],
          );
        }
      }
    }
    return null;
  }

  void _addSlot(BuildContext context) {
    int day = 1;
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 10, minute: 0);
    String? timeError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(tr('schedule_add_slot')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: day,
                decoration: InputDecoration(labelText: tr('schedule_day')),
                items: List.generate(7, (i) {
                  return DropdownMenuItem(
                    value: i + 1,
                    child: Text(tr(_dayKeys[i])),
                  );
                }),
                onChanged: (v) => setDialogState(() => day = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: start,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            start = picked;
                            final s = start.hour * 60 + start.minute;
                            final e = end.hour * 60 + end.minute;
                            timeError = s >= e ? tr('schedule_time_error') : null;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: tr('schedule_start_time'),
                        ),
                        child: Text(
                          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: end,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            end = picked;
                            final s = start.hour * 60 + start.minute;
                            final e = end.hour * 60 + end.minute;
                            timeError = s >= e ? tr('schedule_time_error') : null;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: tr('schedule_end_time'),
                        ),
                        child: Text(
                          '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (timeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    timeError!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('common_cancel')),
            ),
            ElevatedButton(
              onPressed: timeError != null
                  ? null
                  : () {
                      final conflict = _findConflict(day, start, end);
                      if (conflict != null) {
                        Navigator.pop(ctx);
                        _showConflictDialog(context, conflict, day, start, end);
                        return;
                      }
                      _doAddSlot(day, start, end);
                      Navigator.pop(ctx);
                    },
              child: Text(tr('common_add')),
            ),
          ],
        ),
      ),
    );
  }

  void _doAddSlot(int day, TimeOfDay start, TimeOfDay end) {
    entry.schedules.add(_ScheduleSlot(
      dayOfWeek: day,
      startTime:
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
      endTime:
          '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
    ));
    onChanged();
  }

  void _showConflictDialog(
    BuildContext context,
    ({String courseName, String dayKey}) conflict,
    int day,
    TimeOfDay start,
    TimeOfDay end,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('common_confirm')),
        content: Text(
          tr('schedule_conflict_warning',
              args: [conflict.courseName, tr(conflict.dayKey)]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _doAddSlot(day, start, end);
            },
            child: Text(tr('common_add')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courseColor = Color(entry.colorValue);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: courseColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${tr('nav_courses')} ${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: entry.nameController,
              decoration: InputDecoration(
                labelText: tr('course_name'),
                hintText: tr('course_name_hint'),
              ),
            ),
            const SizedBox(height: 12),

            if (!hideAttendance) ...[
              TextFormField(
                controller: entry.requirementController,
                decoration: InputDecoration(
                  labelText: tr('course_attendance_req'),
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
            ],

            Wrap(
              spacing: 8,
              children: courseColors.map((c) {
                final isSelected = c.toARGB32() == entry.colorValue;
                return GestureDetector(
                  onTap: () {
                    entry.colorValue = c.toARGB32();
                    onChanged();
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.onSurface,
                              width: 2.5,
                            )
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Text(
                  tr('course_schedule'),
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _addSlot(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr('schedule_add_slot')),
                ),
              ],
            ),
            ...entry.schedules.asMap().entries.map((e) {
              final slot = e.value;
              final slotIndex = e.key;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, size: 20),
                title: Text(
                  '${tr(_dayKeys[slot.dayOfWeek - 1])}  ${slot.startTime} - ${slot.endTime}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: entry.schedules.length > 1
                      ? () {
                          entry.schedules.removeAt(slotIndex);
                          onChanged();
                        }
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
