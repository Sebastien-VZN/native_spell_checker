/// A Flutter plugin for native OS spell checking on desktop (Windows, Linux).
///
/// Uses the operating system's built-in spell checker — zero bundled
/// dictionaries. On Android, defers to Flutter's
/// [DefaultSpellCheckService].
library;

import 'package:flutter/widgets.dart';
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

  /// Returns the platform-appropriate [NativeSpellCheckService], or `null`
  /// on platforms where the OS spell checker is not available (e.g. Android,
  /// where Flutter's [DefaultSpellCheckService] is used instead).
  static NativeSpellCheckService? get service => NativeSpellCheckService.instance;

  /// Returns a [SpellCheckConfiguration] wired to the native OS spell checker.
  ///
  /// On Android, returns `const SpellCheckConfiguration()` (empty) so Flutter
  /// uses [DefaultSpellCheckService] automatically.
  static SpellCheckConfiguration configuration({TextStyle? misspelledTextStyle}) {
    final svc = service;
    if (svc != null) {
      return SpellCheckConfiguration(
        spellCheckService: svc as SpellCheckService,
        misspelledTextStyle: misspelledTextStyle,
      );
    }
    // Android: let Flutter use DefaultSpellCheckService.
    return const SpellCheckConfiguration();
  }
}
