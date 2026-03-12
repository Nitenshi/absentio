import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class SemesterListScreen extends ConsumerStatefulWidget {
  const SemesterListScreen({super.key});

  @override
  ConsumerState<SemesterListScreen> createState() =>
      _SemesterListScreenState();
}

class _SemesterListScreenState extends ConsumerState<SemesterListScreen> {
  late Future<List<Semester>> _semestersFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _semestersFuture = ref.read(semesterDaoProvider).getAllSemesters();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('semester_list_title')),
      ),
      body: FutureBuilder<List<Semester>>(
        future: _semestersFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final semesters = snapshot.data!;
          if (semesters.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(tr('semester_no_semesters'),
                        style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: semesters.length,
            itemBuilder: (context, index) {
              final s = semesters[index];
              final startStr =
                  '${s.startDate.day.toString().padLeft(2, '0')}/${s.startDate.month.toString().padLeft(2, '0')}/${s.startDate.year}';
              final endStr =
                  '${s.endDate.day.toString().padLeft(2, '0')}/${s.endDate.month.toString().padLeft(2, '0')}/${s.endDate.year}';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (s.isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tr('semester_active_badge'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    tr('semester_date_range',
                        args: [startStr, endStr]),
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (ctx) => [
                      if (!s.isActive)
                        PopupMenuItem(
                          value: 'activate',
                          child: Text(tr('semester_set_active')),
                        ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(tr('common_edit')),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          tr('common_delete'),
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                    onSelected: (action) async {
                      switch (action) {
                        case 'activate':
                          await ref
                              .read(semesterDaoProvider)
                              .setActiveSemester(s.id);
                          setState(() => _reload());
                        case 'edit':
                          await context
                              .push('/settings/semesters/${s.id}/edit');
                          if (mounted) setState(() => _reload());
                        case 'delete':
                          _confirmDelete(s);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push(AppRoutes.semesterAdd);
          if (mounted) setState(() => _reload());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(Semester semester) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('semester_delete')),
        content: Text(tr('semester_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common_cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(semesterDaoProvider).deleteSemester(semester.id);
              if (mounted) setState(() => _reload());
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(tr('common_delete')),
          ),
        ],
      ),
    );
  }
}
