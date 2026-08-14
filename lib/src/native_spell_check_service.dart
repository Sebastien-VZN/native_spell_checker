import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:native_spell_checker/src/linux_spell_check.dart';
import 'package:native_spell_checker/src/native_spell_check_backend.dart';
import 'package:native_spell_checker/src/windows_spell_check.dart';

/// A [SpellCheckService] that delegates to the operating system's native
/// spell checker.
///
/// - **Windows**: Uses WinRT `ISpellChecker2` via the `win32` package.
/// - **Linux**: Uses `libhunspell-1.7` via `dart:ffi`.
/// - **Android**: Returns `null` from [instance] so Flutter falls back to
///   `DefaultSpellCheckService`.
class NativeSpellCheckService extends SpellCheckService {
  NativeSpellCheckService._internal(this._delegate);

  static NativeSpellCheckService? _instance;

  final NativeSpellCheckBackend _delegate;

  /// The text from the last successful [fetchSpellCheckSuggestions] call.
  ///
  /// Used by [findSuggestionSpanAt] to detect stale cache — when the text
  /// has changed since the last spell check, the cache is invalidated.
  String? _lastText;

  /// The suggestion spans from the last successful
  /// [fetchSpellCheckSuggestions] call.
  List<SuggestionSpan>? _lastSpans;

  /// Returns the platform-appropriate [NativeSpellCheckService], or `null`
  /// on Android (where Flutter's [DefaultSpellCheckService] is used).
  ///
  /// The instance is memoized: the OS backend (and its COM session on Windows)
  /// is constructed once per process and reused across calls.
  static NativeSpellCheckService? get instance {
    if (_instance != null) return _instance;
    if (Platform.isWindows) {
      _instance = NativeSpellCheckService._internal(WindowsSpellCheckService());
    } else if (Platform.isLinux) {
      _instance = NativeSpellCheckService._internal(LinuxSpellCheckService());
    }
    // Android: _instance stays null → Flutter uses DefaultSpellCheckService.
    return _instance;
  }

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) async {
    final result = await _delegate.fetchSpellCheckSuggestions(locale, text);
    if (result != null) {
      _lastText = text;
      _lastSpans = result;
    }
    return result;
  }

  /// Returns the [SuggestionSpan] covering [offset] in [text], or `null`
  /// when no cached spell-check result is available or the text has changed
  /// since the last [fetchSpellCheckSuggestions] call.
  ///
  /// This is a synchronous lookup into the last spell-check result — it does
  /// not trigger a new OS spell check. It is designed to be called from a
  /// context menu builder, which must be synchronous.
  SuggestionSpan? findSuggestionSpanAt(String text, int offset) {
    if (_lastText != text || _lastSpans == null) return null;
    for (final span in _lastSpans!) {
      if (offset >= span.range.start && offset <= span.range.end) {
        return span;
      }
    }
    return null;
  }

  /// Returns the OS-resolved language tag for [locale] (or the platform
  /// default locale when [locale] is `null`), or `null` when no backend is
  /// available.
  ///
  /// See [NativeSpellCheckBackend.resolvedLanguageTag] for the exact tag
  /// format per platform.
  Future<String?> resolvedLanguageTag({Locale? locale}) {
    return _delegate.resolvedLanguageTag(locale: locale);
  }
}
