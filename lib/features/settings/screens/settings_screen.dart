import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/services/update_service.dart';
import '../../../core/widgets/update_dialog.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _checkForUpdate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updateInfo = await UpdateService.checkForUpdate(ignoreSkipped: true);
      if (!context.mounted) return;
      if (updateInfo != null) {
        final currentVersion = await UpdateService.getCurrentVersion();
        if (!context.mounted) return;
        UpdateDialog.show(context, updateInfo, currentVersion);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(tr('update_no_update'))),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('update_check_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final currentLocale = context.locale;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('settings_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(title: tr('settings_language')),
          RadioGroup<String>(
            groupValue: currentLocale.languageCode,
            onChanged: (v) {
              if (v != null) context.setLocale(Locale(v));
            },
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Türkçe'),
                  value: 'tr',
                ),
                RadioListTile<String>(
                  title: const Text('English'),
                  value: 'en',
                ),
              ],
            ),
          ),
          const Divider(),

          _SectionHeader(title: tr('settings_theme')),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (v) {
              if (v != null) ref.read(themeModeProvider.notifier).setThemeMode(v);
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(tr('settings_theme_light')),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(tr('settings_theme_dark')),
                  value: ThemeMode.dark,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(tr('settings_theme_system')),
                  value: ThemeMode.system,
                ),
              ],
            ),
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(tr('settings_semesters')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.semesterList),
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: Text(tr('update_check')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _checkForUpdate(context),
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(tr('settings_about')),
            subtitle: Text(tr('settings_version', args: ['1.0.0'])),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
