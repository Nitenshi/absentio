import 'package:drift/drift.dart' hide Column;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class SemesterSetupScreen extends ConsumerStatefulWidget {
  const SemesterSetupScreen({super.key});

  @override
  ConsumerState<SemesterSetupScreen> createState() =>
      _SemesterSetupScreenState();
}

class _SemesterSetupScreenState extends ConsumerState<SemesterSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 112));
  bool _saving = false;
  bool _hasWeekendClasses = true;
  bool _uniformAttendanceReq = false;
  final _globalReqController = TextEditingController(text: '60');

  final List<_ExamPeriodEntry> _examPeriods = [];

  String _fmtDuration(({int weeks, int days}) wd) {
    return AppConstants.formatWeeksDays(wd, tr('unit_weeks'), tr('unit_days'));
  }

  ({int weeks, int days}) get _totalDuration =>
      AppConstants.totalDuration(_startDate, _endDate);

  ({int weeks, int days}) get _examDuration {
    final periods = _examPeriods
        .map((e) => (start: e.startDate, end: e.endDate, classesHeld: e.classesHeld))
        .toList();
    return AppConstants.examDuration(periods, hasWeekendClasses: _hasWeekendClasses);
  }

  ({int weeks, int days}) get _effectiveDuration {
    final periods = _examPeriods
        .map((e) => (start: e.startDate, end: e.endDate, classesHeld: e.classesHeld))
        .toList();
    return AppConstants.effectiveDuration(
      semesterStart: _startDate,
      semesterEnd: _endDate,
      examPeriods: periods,
      hasWeekendClasses: _hasWeekendClasses,
    );
  }

  ({int weeks, int days}) get _remainingDuration {
    final examDays = _examDuration.weeks * 7 + _examDuration.days;
    final effectiveDays = _effectiveDuration.weeks * 7 + _effectiveDuration.days;
    final total = examDays + effectiveDays;
    return (weeks: total ~/ 7, days: total % 7);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _globalReqController.dispose();
    for (final p in _examPeriods) {
      p.nameController.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime current,
    required ValueChanged<DateTime> onPicked,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2040),
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  void _addExamPeriod() {
    setState(() {
      _examPeriods.add(_ExamPeriodEntry(
        startDate: _startDate.add(const Duration(days: 49)),
        endDate: _startDate.add(const Duration(days: 56)),
      ));
    });
  }

  void _removeExamPeriod(int index) {
    setState(() {
      _examPeriods[index].nameController.dispose();
      _examPeriods.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    for (int i = 0; i < _examPeriods.length; i++) {
      for (int j = i + 1; j < _examPeriods.length; j++) {
        final a = _examPeriods[i];
        final b = _examPeriods[j];
        if (!(a.endDate.isBefore(b.startDate) || b.endDate.isBefore(a.startDate))) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('exam_period_overlap_error'))),
          );
          return;
        }
      }
    }

    final semesterDao = ref.read(semesterDaoProvider);
    final allSemesters = await semesterDao.getAllSemesters();
    final trimmedName = _nameController.text.trim().toLowerCase();
    final duplicate = allSemesters.any((s) =>
        s.name.toLowerCase() == trimmedName);
    if (duplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('semester_duplicate_name'))),
        );
      }
      return;
    }

    setState(() => _saving = true);

    final semesterId = await semesterDao.insertSemester(
      SemestersCompanion.insert(
        name: _nameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        isActive: const Value(true),
        hasWeekendClasses: Value(_hasWeekendClasses),
        uniformAttendanceReq: Value(_uniformAttendanceReq),
        globalAttendanceReq: Value(
          (double.tryParse(_globalReqController.text) ?? 60) / 100,
        ),
      ),
    );

    await semesterDao.setActiveSemester(semesterId);

    for (final p in _examPeriods) {
      final name = p.nameController.text.trim();
      await semesterDao.insertExamPeriod(
        ExamPeriodsCompanion.insert(
          semesterId: semesterId,
          startDate: p.startDate,
          endDate: p.endDate,
          name: Value(name.isEmpty ? null : name),
          classesHeld: Value(p.classesHeld),
        ),
      );
    }

    if (mounted) {
      context.go(AppRoutes.courseSetup, extra: semesterId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('semester_setup_title')),
        leading: BackButton(onPressed: () => context.go(AppRoutes.welcome)),
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
                  labelText: tr('semester_name'),
                  hintText: tr('semester_name_hint'),
                ),
                maxLength: 200,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? tr('common_required_field')
                    : null,
              ),
              const SizedBox(height: 16),

              _DateField(
                label: tr('semester_start_date'),
                date: _startDate,
                onTap: () => _pickDate(
                  current: _startDate,
                  onPicked: (d) => _startDate = d,
                  lastDate: _endDate,
                ),
              ),
              const SizedBox(height: 16),

              _DateField(
                label: tr('semester_end_date'),
                date: _endDate,
                onTap: () => _pickDate(
                  current: _endDate,
                  onPicked: (d) => _endDate = d,
                  firstDate: _startDate,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                tr('semester_total_weeks_computed',
                    args: [_fmtDuration(_totalDuration)]),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                title: Text(tr('semester_has_weekend_classes')),
                value: _hasWeekendClasses,
                onChanged: (v) => setState(() => _hasWeekendClasses = v),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 8),

              SwitchListTile(
                title: Text(tr('semester_uniform_attendance')),
                value: _uniformAttendanceReq,
                onChanged: (v) => setState(() => _uniformAttendanceReq = v),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              if (_uniformAttendanceReq) ...[                const SizedBox(height: 8),
                TextFormField(
                  controller: _globalReqController,
                  decoration: InputDecoration(
                    labelText: tr('semester_uniform_attendance_req'),
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
              const SizedBox(height: 24),

              Row(
                children: [
                  Text(
                    tr('exam_period_title'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addExamPeriod,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(tr('exam_period_add')),
                  ),
                ],
              ),
              if (_examPeriods.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    tr('common_no_data'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                )
              else
                ..._examPeriods.asMap().entries.map((e) {
                  final idx = e.key;
                  final period = e.value;
                  return _ExamPeriodCard(
                    period: period,
                    index: idx,
                    onRemove: () => _removeExamPeriod(idx),
                    onPickStart: () => _pickDate(
                      current: period.startDate,
                      onPicked: (d) => period.startDate = d,
                      firstDate: _startDate,
                      lastDate: period.endDate,
                    ),
                    onPickEnd: () => _pickDate(
                      current: period.endDate,
                      onPicked: (d) => period.endDate = d,
                      firstDate: period.startDate,
                      lastDate: _endDate,
                    ),
                    onClassesHeldChanged: (v) {
                      setState(() => period.classesHeld = v);
                    },
                  );
                }),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (_examPeriods.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          tr('semester_exam_weeks_computed',
                              args: [_fmtDuration(_examDuration)]),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    Text(
                      tr('semester_effective_weeks',
                          args: [_fmtDuration(_effectiveDuration)]),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_examPeriods.isNotEmpty) ...[                      const SizedBox(height: 4),
                      Text(
                        tr('semester_remaining_duration',
                            args: [_fmtDuration(_remainingDuration)]),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr('onboarding_next')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamPeriodEntry {
  final TextEditingController nameController = TextEditingController();
  DateTime startDate;
  DateTime endDate;
  bool classesHeld;

  _ExamPeriodEntry({
    required this.startDate,
    required this.endDate,
  }) : classesHeld = false;
}

class _ExamPeriodCard extends StatelessWidget {
  final _ExamPeriodEntry period;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<bool> onClassesHeldChanged;

  const _ExamPeriodCard({
    required this.period,
    required this.index,
    required this.onRemove,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClassesHeldChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${tr('exam_period_title')} ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            TextFormField(
              controller: period.nameController,
              decoration: InputDecoration(
                labelText: tr('exam_period_name'),
                hintText: tr('exam_period_name_hint'),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: tr('exam_period_start'),
                    date: period.startDate,
                    onTap: onPickStart,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: tr('exam_period_end'),
                    date: period.endDate,
                    onTap: onPickEnd,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(
                tr('exam_period_classes_held'),
                style: theme.textTheme.bodyMedium,
              ),
              value: period.classesHeld,
              onChanged: onClassesHeldChanged,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
