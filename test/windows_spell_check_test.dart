import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:win32/win32.dart';

import 'package:native_spell_checker/native_spell_checker.dart';

/// Calls Win32 `GetUserDefaultLocaleName` directly (no COM) to obtain the
/// authoritative system-default language tag — the same Win32 API the plugin
/// uses as the fallback inside `_resolveLanguageTag`. We avoid comparing
/// against `Platform.localeName` because under `flutter test` it returns a
/// sandbox default (`en_US`, POSIX-formatted) rather than the actual host
/// locale — so it can't be trusted as ground truth in tests.
String _systemDefaultLanguageTag() {
  return using((arena) {
    final lpLocaleName = arena.pwstrBuffer(LOCALE_NAME_MAX_LENGTH);
    final result = GetUserDefaultLocaleName(lpLocaleName, LOCALE_NAME_MAX_LENGTH);
    if (result.value <= 0) {
      throw StateError('GetUserDefaultLocaleName failed (HRESULT=${result.value}).');
    }
    return lpLocaleName.toDartString();
  });
}

void main() {
  if (Platform.isWindows) {
    group('WindowsSpellCheckService — live', () {
      test('fetchSpellCheckSuggestions returns non-empty suggestions for a misspelled word', () async {
        final service = NativeSpellChecker.service;
        expect(service, isNotNull, reason: 'WindowsSpellCheckService must be available on Windows.');
        final List<SuggestionSpan>? result = await service!.fetchSpellCheckSuggestions(
          const Locale('en', 'US'),
          'hello wrld',
        );
        expect(result, isA<List<SuggestionSpan>>());
        expect(result, isNotNull);
        expect(result!, isNotEmpty);
        expect(result.first, isA<SuggestionSpan>());
        expect(result.first.suggestions, isNotEmpty);
      });

      test('fetchSpellCheckSuggestions returns an empty list for correct text', () async {
        final service = NativeSpellChecker.service;
        expect(service, isNotNull);
        final List<SuggestionSpan>? result = await service!.fetchSpellCheckSuggestions(
          const Locale('en', 'US'),
          'hello world',
        );
        expect(result, isA<List<SuggestionSpan>>());
        expect(result, isNotNull);
        expect(result!, isEmpty);
      });

      test('repeated calls stay consistent (COM apartment does not break)', () async {
        final service = NativeSpellChecker.service;
        expect(service, isNotNull);
        for (var i = 0; i < 3; i++) {
          final List<SuggestionSpan>? result = await service!.fetchSpellCheckSuggestions(
            const Locale('en', 'US'),
            'wrld',
          );
          expect(result, isNotNull);
          expect(result!, isNotEmpty);
        }
      });
    });

    group('WindowsSpellCheckService.resolvedLanguageTag — live', () {
      test('with no locale matches GetUserDefaultLocaleName (system default)', () async {
        final service = NativeSpellChecker.service;
        expect(service, isNotNull, reason: 'WindowsSpellCheckService must be available on Windows.');
        final tag = await service!.resolvedLanguageTag();
        expect(tag, isNotNull, reason: 'System-default + en-US fallback chain is never null.');
        // The plugin's no-locale path skips the requested-locale step and goes
        // straight to the system default. Verify against the same Win32 API.
        expect(tag, _systemDefaultLanguageTag(), reason: 'No-locale resolution must match the OS default tag.');
      });

      test('requesting the system-default locale explicitly round-trips', () async {
        final service = NativeSpellChecker.service;
        expect(service, isNotNull);
        final defaultTag = await service!.resolvedLanguageTag();
        expect(defaultTag, isNotNull);
        // Reconstruct a Locale from the default tag and request it explicitly:
        // the factory reports it as supported, so resolution returns itself.
        final parts = defaultTag!.split('-');
        final locale = Locale(parts[0].toLowerCase(), parts.length > 1 ? parts.last.toUpperCase() : null);
        final tag = await service.resolvedLanguageTag(locale: locale);
        expect(tag, defaultTag, reason: 'The system default must round-trip when requested explicitly.');
      });

      test('falls back to a non-null tag for an unsupported locale (system default → en-US)', () async {
        final service = NativeSpellChecker.service;
        expect(service, isNotNull);
        final tag = await service!.resolvedLanguageTag(locale: const Locale('zz', 'ZZ'));
        expect(tag, isNotNull, reason: 'Windows fallback chain never yields null.');
        expect(tag!, isNotEmpty);
      });

      test('resolvedLanguageTag matches the dictionary fetchSpellCheckSuggestions will use', () async {
        final service = NativeSpellChecker.service;
        expect(service, isNotNull);
        // Use the system-default locale (guaranteed supported by the factory).
        final defaultTag = await service!.resolvedLanguageTag();
        expect(defaultTag, isNotNull);
        final parts = defaultTag!.split('-');
        final locale = Locale(parts[0].toLowerCase(), parts.length > 1 ? parts.last.toUpperCase() : null);
        // Both functions share the same `_resolveLanguageTag` code path, so the
        // resolved tag is the exact language `createSpellChecker` receives.
        // Spell-checking an obviously-misspelled word under that locale must
        // succeed and produce suggestions — i.e. the resolved dictionary works.
        final List<SuggestionSpan>? result = await service.fetchSpellCheckSuggestions(locale, 'wrld');
        expect(result, isNotNull);
        expect(result, isA<List<SuggestionSpan>>());
        expect(result!, isNotEmpty, reason: 'wrld must yield suggestions in any installed language.');
        expect(result.first.suggestions, isNotEmpty);
      });

      test('repeated calls are stable (COM apartment does not break across isolates)', () async {
        final service = NativeSpellChecker.service;
        expect(service, isNotNull);
        final first = await service!.resolvedLanguageTag();
        expect(first, isNotNull);
        for (var i = 0; i < 3; i++) {
          final next = await service.resolvedLanguageTag();
          expect(next, first);
        }
      });

      test('interleaves with fetchSpellCheckSuggestions without COM state corruption', () async {
        final service = NativeSpellChecker.service;
        expect(service, isNotNull);
        // Two COM workloads run on concurrent worker isolates: ensure the
        // per-isolate `_comInitialized` static doesn't corrupt either path.
        final tagFuture = service!.resolvedLanguageTag();
        final suggestFuture = service.fetchSpellCheckSuggestions(const Locale('en', 'US'), 'hello wrld');
        final tag = await tagFuture;
        final List<SuggestionSpan>? suggestions = await suggestFuture;
        expect(tag, isNotNull);
        expect(suggestions, isNotNull);
      });
    });
  } else {
    test('Windows-only test file does not run assertions on non-Windows platforms', () {
      expect(Platform.isWindows, isFalse);
    });
  }
}
