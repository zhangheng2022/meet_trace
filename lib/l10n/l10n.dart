import 'package:flutter/widgets.dart';

import '../domain/models/app_language.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension AppLanguageModeLocale on AppLanguageMode {
  Locale? get locale => switch (this) {
    AppLanguageMode.system => null,
    AppLanguageMode.simplifiedChinese => const Locale('zh'),
    AppLanguageMode.english => const Locale('en'),
  };
}

Locale resolveAppLocale(Locale? systemLocale) =>
    systemLocale?.languageCode.toLowerCase() == 'zh'
    ? const Locale('zh')
    : const Locale('en');
