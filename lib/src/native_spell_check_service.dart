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

  static NativeSpellCheckService? _instance;

  final SpellCheckService _delegate;

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
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) {
    return _delegate.fetchSpellCheckSuggestions(locale, text);
  }
}