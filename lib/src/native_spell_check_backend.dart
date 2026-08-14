import 'package:flutter/services.dart';

import 'package:flutter/material.dart' show Locale;

/// Common surface implemented by each platform spell-check backend
/// ([WindowsSpellCheckService], [LinuxSpellCheckService]).
///
/// Lets [NativeSpellCheckService] delegate to platform-specific methods
/// (such as [resolvedLanguageTag]) without an ad-hoc `is`/cast per platform.
abstract class NativeSpellCheckBackend extends SpellCheckService {
  /// Returns the language tag of the dictionary the OS spell checker will
  /// actually use for [locale], or `null` when no backend is available.
  ///
  /// The string format follows each platform's convention:
  /// - **Windows**: BCP-47 tag (e.g. `"fr-FR"`, `"en-US"`).
  /// - **Linux**: Hunspell dictionary name (e.g. `"fr_FR"`, `"en_US"`).
  ///
  /// When [locale] is `null`, the platform default locale is used — i.e. the
  /// language the spell checker would select on its own. Resolution applies
  /// the same fallback chain used during spell checking: requested locale →
  /// system default → fixed last resort (`"en-US"` on Windows).
  Future<String?> resolvedLanguageTag({Locale? locale});
}
