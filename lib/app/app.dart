import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/providers/settings_provider.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class AbsentioApp extends ConsumerStatefulWidget {
  final bool onboardingComplete;

  const AbsentioApp({super.key, required this.onboardingComplete});

  @override
  ConsumerState<AbsentioApp> createState() => _AbsentioAppState();
}

class _AbsentioAppState extends ConsumerState<AbsentioApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(onboardingComplete: widget.onboardingComplete);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Absentio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: _router,
    );
  }
}
