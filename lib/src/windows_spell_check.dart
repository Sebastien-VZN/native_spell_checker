import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:win32/win32.dart';

/// Windows spell check service backed by WinRT `ISpellChecker2`.
///
/// Uses the `win32` package to call the Windows COM SpellChecker API directly
/// via FFI. No native code to compile — all FFI is handled by the `win32`
/// package.
class WindowsSpellCheckService extends SpellCheckService {
  /// Creates a [WindowsSpellCheckService].
  WindowsSpellCheckService();

  bool _comInitialized = false;

  void _ensureComInit() {
    if (_comInitialized) return;
    final hr = CoInitializeEx(COINIT_MULTITHREADED);
    // S_FALSE (1) means already initialized on this thread — that's fine.
    if (hr.isError && hr != S_FALSE) {
      throw WindowsException(hr);
    }
    _comInitialized = true;
  }

  /// Converts a [Locale] to a Windows language tag (e.g. "fr-FR", "en-US").
  String _localeToLanguageTag(Locale locale) {
    final language = locale.languageCode.toLowerCase();
    final country = locale.countryCode?.toUpperCase();
    if (country != null && country.isNotEmpty) {
      return '$language-$country';
    }
    return language;
  }

  /// Resolves the language tag, falling back to the system default if the
  /// requested locale is not supported.
  String _resolveLanguageTag(ISpellCheckerFactory factory, Arena arena, Locale locale) {
    final requestedTag = _localeToLanguageTag(locale);
    if (factory.isSupported(arena.pcwstr(requestedTag))) {
      return requestedTag;
    }

    // Fall back to system default locale.
    final lpLocaleName = arena.pwstrBuffer(LOCALE_NAME_MAX_LENGTH);
    final result = GetUserDefaultLocaleName(lpLocaleName, LOCALE_NAME_MAX_LENGTH);
    if (result.value > 0) {
      final systemTag = lpLocaleName.toDartString();
      if (factory.isSupported(arena.pcwstr(systemTag))) {
        return systemTag;
      }
    }

    // Last resort: en-US.
    return 'en-US';
  }

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) async {
    if (text.isEmpty) return <SuggestionSpan>[];

    try {
      return _checkInternal(locale, text);
    } on Exception {
      return null;
    }
  }

  List<SuggestionSpan> _checkInternal(Locale locale, String text) {
    _ensureComInit();

    return using((arena) {
      final factory = arena.com<ISpellCheckerFactory>(SpellCheckerFactory);
      final languageTag = _resolveLanguageTag(factory, arena, locale);
      final checker = arena.adopt(factory.createSpellChecker(arena.pcwstr(languageTag))!);
      final checker2 = arena.adopt(checker.queryInterface<ISpellChecker2>());

      final errors = checker2.comprehensiveCheck(arena.pcwstr(text))!;
      final spans = <SuggestionSpan>[];

      final errorPtr = arena<VTablePointer>();
      while (errors.next(errorPtr) == S_OK) {
        final error = arena.adopt(ISpellingError(errorPtr.value));
        final start = error.startIndex;
        final length = error.length;
        final word = text.substring(start, start + length);

        switch (error.correctiveAction) {
          case CORRECTIVE_ACTION_DELETE:
            // No suggestions for delete actions.
            spans.add(SuggestionSpan(TextRange(start: start, end: start + length), <String>[]));

          case CORRECTIVE_ACTION_REPLACE:
            final replacement = error.replacement.toDartString();
            spans.add(SuggestionSpan(TextRange(start: start, end: start + length), <String>[replacement]));

          case CORRECTIVE_ACTION_GET_SUGGESTIONS:
            final suggestions = _collectSuggestions(checker2, word, arena);
            spans.add(SuggestionSpan(TextRange(start: start, end: start + length), suggestions));

          default:
            break;
        }
      }

      return spans;
    });
  }

  /// Collects suggestions for a misspelled word from the spell checker.
  List<String> _collectSuggestions(ISpellChecker2 checker, String word, Arena arena) {
    final suggestions = <String>[];
    final enumSuggestions = arena.adopt(checker.suggest(arena.pcwstr(word))!);
    final fetched = arena<ULONG>();
    final ptr = arena<Pointer<Utf16>>();

    while (enumSuggestions.next(1, ptr, fetched) == S_OK && fetched.value == 1) {
      final p = ptr[0];
      if (p.isNull) break;
      suggestions.add(p.toDartString());
      free(p);
    }

    return suggestions;
  }
}
