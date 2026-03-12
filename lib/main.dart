import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/constants/app_constants.dart';

const kDevAlwaysShowSetup = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = kDevAlwaysShowSetup
      ? false
      : (prefs.getBool(AppConstants.keyOnboardingComplete) ?? false);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('tr')],
      path: 'assets/l10n',
      fallbackLocale: const Locale('en'),
      child: ProviderScope(
        child: AbsentioApp(onboardingComplete: onboardingComplete),
      ),
    ),
  );
}
