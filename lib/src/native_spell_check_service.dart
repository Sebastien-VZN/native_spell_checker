import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:native_spell_checker/src/linux_spell_check.dart';
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

  final SpellCheckService _delegate;

  /// Returns the platform-appropriate [NativeSpellCheckService], or `null`
  /// on Android (where Flutter's `DefaultSpellCheckService` is used).
  static NativeSpellCheckService? get instance {
    if (Platform.isWindows) {
      return NativeSpellCheckService._internal(WindowsSpellCheckService());
    }
    if (Platform.isLinux) {
      return NativeSpellCheckService._internal(LinuxSpellCheckService());
    }
    // Android: null → Flutter uses DefaultSpellCheckService.
    return null;
  }

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) {
    return _delegate.fetchSpellCheckSuggestions(locale, text);
  }
}
