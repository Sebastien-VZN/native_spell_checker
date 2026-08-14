/// A Flutter plugin for native OS spell checking on desktop (Windows, Linux).
///
/// Uses the operating system's built-in spell checker — zero bundled
/// dictionaries. On Android, defers to Flutter's
/// [DefaultSpellCheckService].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:native_spell_checker/src/native_spell_check_service.dart';

export 'package:flutter/widgets.dart' show SpellCheckConfiguration;

/// Entry point for the native spell checker plugin.
///
/// On desktop platforms (Windows, Linux), returns a [NativeSpellCheckService]
/// that wraps the OS spell checker. On Android, returns `null` so Flutter
/// falls back to [DefaultSpellCheckService] automatically.
class NativeSpellChecker {
  const NativeSpellChecker._();

  static const TextStyle _defaultMisspelledTextStyle = TextStyle(
    decoration: TextDecoration.underline,
    decorationColor: Colors.red,
    decorationStyle: TextDecorationStyle.wavy,
  );

  /// Required by Flutter's plugin registration system for federated plugins
  /// using `dartPluginClass`. This plugin is pure Dart (no native code), so
  /// registration is a no-op.
  static void registerWith() {
    // No-op — no native platform channel to register.
  }

  /// Returns the platform-appropriate [NativeSpellCheckService], or `null`
  /// on platforms where the OS spell checker is not available (e.g. Android,
  /// where Flutter's [DefaultSpellCheckService] is used instead).
  static NativeSpellCheckService? get service => NativeSpellCheckService.instance;

  /// Returns the language tag of the dictionary the OS spell checker will
  /// actually use for [locale] (or the platform default locale when [locale]
  /// is `null`), or `null` when no backend is available (Android).
  ///
  /// On desktop, this performs the same fallback chain used during spell
  /// checking: requested locale → system default → fixed last resort
  /// (`"en-US"` on Windows).
  ///
  /// The string format follows each platform's convention:
  /// - **Windows**: BCP-47 tag (e.g. `"fr-FR"`, `"en-US"`).
  /// - **Linux**: Hunspell dictionary name (e.g. `"fr_FR"`, `"en_US"`).
  /// - **Android**: always `null` (Flutter's [DefaultSpellCheckService] is
  ///   used). Use `Platform.localeName` to read the system locale instead.
  ///
  /// Example:
  ///
  /// ```dart
  /// final tag = await NativeSpellChecker.resolvedLanguageTag();
  /// print('Native spell check language: $tag');
  /// ```
  static Future<String?> resolvedLanguageTag({Locale? locale}) {
    return NativeSpellCheckService.instance?.resolvedLanguageTag(locale: locale) ?? Future<String?>.value(null);
  }

  /// Returns a [SpellCheckConfiguration] wired to the native OS spell checker.
  ///
  /// On Android, returns `const SpellCheckConfiguration()` (empty) so Flutter
  /// uses [DefaultSpellCheckService] automatically.
  static SpellCheckConfiguration configuration({TextStyle? misspelledTextStyle}) {
    final svc = service;
    if (svc != null) {
      return SpellCheckConfiguration(
        spellCheckService: svc,
        misspelledTextStyle: misspelledTextStyle ?? _defaultMisspelledTextStyle,
      );
    }
    // Android: let Flutter use DefaultSpellCheckService.
    return const SpellCheckConfiguration();
  }
}
