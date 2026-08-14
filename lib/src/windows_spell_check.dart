import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_spell_checker/src/native_spell_check_backend.dart';
import 'package:win32/win32.dart';

/// Windows spell check service backed by WinRT `ISpellChecker2`.
///
/// Uses the `win32` package to call the Windows COM SpellChecker API directly
/// via FFI. No native code to compile — all FFI is handled by the `win32`
/// package.
///
/// The whole COM call ([_spawnCheck]) runs in a worker [Isolate] (MTA) so the
/// UI thread is never blocked: a single spell-check takes ~200 ms on Windows,
/// which would otherwise freeze the UI at every keystroke.
class WindowsSpellCheckService extends NativeSpellCheckBackend {
  /// Creates a [WindowsSpellCheckService].
  WindowsSpellCheckService();

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) async {
    if (text.isEmpty) return <SuggestionSpan>[];

    try {
      // Run the COM-bound work on a fresh worker Isolate. `Isolate.run`
      // spawns an isolate in the MTA apartment, executes the computation,
      // and returns the (serialized) result to the UI isolate. The closure
      // only captures `text` (Dart-serializable), so it crosses the isolate
      // boundary cleanly — no `this` capture.
      //
      // Pass null as the locale so _resolveLanguageTag uses the OS native
      // locale (GetUserDefaultLocaleName) instead of the one Flutter passes,
      // which defaults to en_US when the app doesn't declare supportedLocales.
      return await Isolate.run<List<SuggestionSpan>>(() => _spawnCheck(null, text));
    } on Exception catch (err) {
      debugPrint('WindowsSpellCheckService.fetchSpellCheckSuggestions: $err');
      return null;
    }
  }

  @override
  Future<String?> resolvedLanguageTag({Locale? locale}) async {
    try {
      // Resolution needs the COM `ISpellCheckerFactory.isSupported` check,
      // so it must run on the worker Isolate (MTA) — same rationale as
      // [fetchSpellCheckSuggestions]. The closure only captures `locale`
      // (Dart-serializable), no `this` capture.
      return await Isolate.run<String>(() => _resolveLanguageTagInIsolate(locale));
    } on Exception catch (err) {
      debugPrint('WindowsSpellCheckService.resolvedLanguageTag: $err');
      return null;
    }
  }

  // --- Everything below is static: it runs in the worker Isolate and must
  //     not capture `this`. The COM init flag is per-Isolate (each spawned
  //     worker gets its own copy, initialized to false). ---

  static bool _comInitialized = false;

  static void _ensureComInit() {
    if (_comInitialized) return;
    final hr = CoInitializeEx(COINIT_APARTMENTTHREADED);
    // S_FALSE: already initialized on this thread with the same apartment.
    // RPC_E_CHANGED_MODE: already initialized with a different apartment
    //   (the worker Isolate thread is MTA). The existing apartment wins;
    //   WinRT SpellChecker objects are agile and work in either — proceed.
    if (hr.isError && hr != S_FALSE && hr != RPC_E_CHANGED_MODE) {
      throw WindowsException(hr);
    }
    _comInitialized = true;
  }

  /// Converts a [Locale] to a Windows language tag (e.g. "fr-FR", "en-US").
  static String _localeToLanguageTag(Locale locale) {
    final language = locale.languageCode.toLowerCase();
    final country = locale.countryCode?.toUpperCase();
    if (country != null && country.isNotEmpty) {
      return '$language-$country';
    }
    return language;
  }

  /// Resolves the language tag, falling back to the system default if the
  /// requested locale is not supported.
  ///
  /// When [locale] is `null`, the requested-locale step is skipped and
  /// resolution starts at the system default locale — i.e. the language the
  /// spell checker would select on its own.
  static String _resolveLanguageTag(ISpellCheckerFactory factory, Arena arena, Locale? locale) {
    if (locale != null) {
      final requestedTag = _localeToLanguageTag(locale);
      if (factory.isSupported(arena.pcwstr(requestedTag))) {
        return requestedTag;
      }
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

  /// Worker-Isolate entry point for [resolvedLanguageTag]: initializes COM
  /// on the MTA thread, creates the factory and returns the resolved tag.
  /// Reuses [_resolveLanguageTag] so resolution is identical to a spell check.
  static String _resolveLanguageTagInIsolate(Locale? locale) {
    _ensureComInit();

    return using((arena) {
      final factory = arena.com<ISpellCheckerFactory>(SpellCheckerFactory);
      return _resolveLanguageTag(factory, arena, locale);
    });
  }

  static List<SuggestionSpan> _spawnCheck(Locale? locale, String text) {
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
  static List<String> _collectSuggestions(ISpellChecker2 checker, String word, Arena arena) {
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
