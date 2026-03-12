import 'package:drift/drift.dart' hide Column;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/course_dao.dart';
import '../../../core/providers/database_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../schedule/providers/schedule_provider.dart';

class CourseFormScreen extends ConsumerStatefulWidget {
  final int? courseId;
  final int? semesterId;

  const CourseFormScreen({super.key, this.courseId, this.semesterId});

  @override
  ConsumerState<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends ConsumerState<CourseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _reqController = TextEditingController(text: '60');
  int _colorValue = 0xFF399DD9;
  bool _loading = true;
  bool _saving = false;
  bool _uniformAttendance = false;
  String _uniformReqDisplay = '60';

  Course? _existingCourse;
  final List<_SlotEntry> _slots = [];
  List<ScheduleWithCourse> _existingSchedules = [];

  static const _colors = [
    Color(0xFF399DD9),
    Color(0xFF39D9B3),
    Color(0xFFE53935),
    Color(0xFFFFA726),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFF5C6BC0),
    Color(0xFF26C6DA),
    Color(0xFFEC407A),
  ];

  static const _dayKeys = [
    'days_mon', 'days_tue', 'days_wed', 'days_thu',
    'days_fri', 'days_sat', 'days_sun',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dao = ref.read(courseDaoProvider);

    if (widget.courseId != null) {
      _existingCourse = await dao.getCourseById(widget.courseId!);
      _nameController.text = _existingCourse!.name;
      _reqController.text =
          (_existingCourse!.attendanceRequirement * 100).toStringAsFixed(0);
      _colorValue = _existingCourse!.color;

      final schedules = await dao.getSchedulesByCourse(widget.courseId!);
      _slots.addAll(schedules.map((s) => _SlotEntry(
            id: s.id,
            dayOfWeek: s.dayOfWeek,
            startTime: s.startTime,
            endTime: s.endTime,
          )));
    }

    final semId = widget.semesterId ?? _existingCourse?.semesterId;
    if (semId != null) {
      _existingSchedules = await dao.getWeeklySchedule(semId);
      final semester = await ref.read(semesterDaoProvider).getSemesterById(semId);
      _uniformAttendance = semester.uniformAttendanceReq;
      _uniformReqDisplay =
          (semester.globalAttendanceReq * 100).toStringAsFixed(0);
    }

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('schedule_add_slot'))),
      );
      return;
    }

    final dao = ref.read(courseDaoProvider);
    final semId = widget.semesterId ?? _existingCourse?.semesterId;
    if (semId != null) {
      final existing = await dao.getCoursesBySemester(semId);
      final trimmedName = _nameController.text.trim().toLowerCase();
      final duplicate = existing.any((c) =>
          c.name.toLowerCase() == trimmedName &&
          c.id != _existingCourse?.id);
      if (duplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('course_duplicate_name'))),
          );
        }
        return;
      }
    }

    setState(() => _saving = true);
    final double req;
    if (_uniformAttendance) {
      req = double.tryParse(_uniformReqDisplay) != null
          ? double.parse(_uniformReqDisplay) / 100
          : 0.60;
    } else {
      req = (double.tryParse(_reqController.text) ?? 60) / 100;
    }

    if (_existingCourse != null) {
      await dao.updateCourse(_existingCourse!.copyWith(
        name: _nameController.text.trim(),
        attendanceRequirement: req,
        color: _colorValue,
      ));

      final existingIds = _slots.where((s) => s.id != null).map((s) => s.id!).toSet();

      final allSchedules = await dao.getSchedulesByCourse(_existingCourse!.id);
      for (final old in allSchedules) {
        if (!existingIds.contains(old.id)) {
          await dao.deleteSchedule(old.id);
        }
      }

      for (final slot in _slots) {
        if (slot.id != null) {
          await dao.updateSchedule(CourseSchedule(
            id: slot.id!,
            courseId: _existingCourse!.id,
            dayOfWeek: slot.dayOfWeek,
            startTime: slot.startTime,
            endTime: slot.endTime,
          ));
        } else {
          await dao.insertSchedule(CourseSchedulesCompanion.insert(
            courseId: _existingCourse!.id,
            dayOfWeek: slot.dayOfWeek,
            startTime: slot.startTime,
            endTime: slot.endTime,
          ));
        }
      }
    } else {
      final semesterId = widget.semesterId!;
      final courseId = await dao.insertCourse(CoursesCompanion.insert(
        semesterId: semesterId,
        name: _nameController.text.trim(),
        attendanceRequirement: Value(req),
        color: Value(_colorValue),
      ));

      for (final slot in _slots) {
        await dao.insertSchedule(CourseSchedulesCompanion.insert(
          courseId: courseId,
          dayOfWeek: slot.dayOfWeek,
          startTime: slot.startTime,
          endTime: slot.endTime,
        ));
      }
    }

    if (mounted) {
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(weeklyScheduleProvider);
      context.pop();
    }
  }

  ({String courseName, String dayKey})? _findConflict(int day, TimeOfDay start, TimeOfDay end) {
    final newStart = start.hour * 60 + start.minute;
    final newEnd = end.hour * 60 + end.minute;

    for (final slot in _slots) {
      if (slot.dayOfWeek != day) continue;
      final parts1 = slot.startTime.split(':');
      final parts2 = slot.endTime.split(':');
      final existStart = int.parse(parts1[0]) * 60 + int.parse(parts1[1]);
      final existEnd = int.parse(parts2[0]) * 60 + int.parse(parts2[1]);
      if (newStart < existEnd && newEnd > existStart) {
        return (
          courseName: _nameController.text.isEmpty ? tr('nav_courses') : _nameController.text,
          dayKey: _dayKeys[day - 1],
        );
      }
    }

    for (final swc in _existingSchedules) {
      if (widget.courseId != null && swc.course.id == widget.courseId) continue;
      if (swc.schedule.dayOfWeek != day) continue;
      final parts1 = swc.schedule.startTime.split(':');
      final parts2 = swc.schedule.endTime.split(':');
      final existStart = int.parse(parts1[0]) * 60 + int.parse(parts1[1]);
      final existEnd = int.parse(parts2[0]) * 60 + int.parse(parts2[1]);
      if (newStart < existEnd && newEnd > existStart) {
        return (courseName: swc.course.name, dayKey: _dayKeys[day - 1]);
      }
    }
    return null;
  }

  void _addSlot() {
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
                      value: i + 1, child: Text(tr(_dayKeys[i])));
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
                            context: ctx, initialTime: start);
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
                            labelText: tr('schedule_start_time')),
                        child: Text(_formatTime(start)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: ctx, initialTime: end);
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
                        decoration:
                            InputDecoration(labelText: tr('schedule_end_time')),
                        child: Text(_formatTime(end)),
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
                        _showConflictDialog(conflict, day, start, end);
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
    setState(() {
      _slots.add(_SlotEntry(
        dayOfWeek: day,
        startTime: _formatTime(start),
        endTime: _formatTime(end),
      ));
    });
  }

  void _showConflictDialog(
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

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _nameController.dispose();
    _reqController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.courseId != null;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? tr('course_edit') : tr('course_add')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: tr('course_name'),
                  hintText: tr('course_name_hint'),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? tr('common_required_field')
                    : null,
              ),
              const SizedBox(height: 16),
              if (_uniformAttendance)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.onSecondaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr('course_attendance_locked',
                              args: [_uniformReqDisplay]),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                TextFormField(
                  controller: _reqController,
                  decoration: InputDecoration(
                    labelText: tr('course_attendance_req'),
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              const SizedBox(height: 16),

              Text(tr('course_color'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colors.map((c) {
                  final isSelected = c.toARGB32() == _colorValue;
                  return GestureDetector(
                    onTap: () => setState(() => _colorValue = c.toARGB32()),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.onSurface, width: 2.5)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Text(tr('course_schedule'),
                      style: theme.textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addSlot,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(tr('schedule_add_slot')),
                  ),
                ],
              ),
              ..._slots.asMap().entries.map((e) {
                final slot = e.value;
                final i = e.key;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule, size: 20),
                  title: Text(
                    '${tr(_dayKeys[slot.dayOfWeek - 1])}  ${slot.startTime} - ${slot.endTime}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: _slots.length > 1
                        ? () => setState(() => _slots.removeAt(i))
                        : null,
                  ),
                );
              }),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr('common_save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotEntry {
  final int? id;
  int dayOfWeek;
  String startTime;
  String endTime;

  _SlotEntry({
    this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });
}
