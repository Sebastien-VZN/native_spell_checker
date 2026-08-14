import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:native_spell_checker/native_spell_checker.dart';

void main() {
  group('NativeSpellChecker', () {
    test('service is null on Android, non-null on desktop', () {
      if (Platform.isAndroid) {
        expect(NativeSpellChecker.service, isNull);
      } else {
        expect(NativeSpellChecker.service, isNotNull);
      }
    });

    test('configuration returns a SpellCheckConfiguration on all platforms', () {
      final SpellCheckConfiguration config = NativeSpellChecker.configuration();
      expect(config, isA<SpellCheckConfiguration>());
    });

    test('configuration respects the provided misspelledTextStyle', () {
      final TextStyle style = TextStyle(color: Colors.red);
      final SpellCheckConfiguration config = NativeSpellChecker.configuration(misspelledTextStyle: style);
      expect(config.misspelledTextStyle, style);
    });

    test('configuration provides a default misspelledTextStyle on desktop', () {
      final SpellCheckConfiguration config = NativeSpellChecker.configuration();
      if (Platform.isAndroid) {
        expect(config.misspelledTextStyle, isNull);
      } else {
        expect(config.misspelledTextStyle, isNotNull);
      }
    });

    test('service is memoized across calls (stable instance)', () {
      final first = NativeSpellChecker.service;
      final second = NativeSpellChecker.service;
      expect(second, same(first));
    });
  });

  group('NativeSpellCheckService — live', () {
    final service = NativeSpellChecker.service;

    test('fetchSpellCheckSuggestions returns an empty list for correct text', () async {
      if (service == null) {
        expect(service, isNull, reason: 'Backend unavailable on this platform.');
      } else {
        final List<SuggestionSpan>? result = await service.fetchSpellCheckSuggestions(
          const Locale('en', 'US'),
          'hello world',
        );
        expect(result, isA<List<SuggestionSpan>>());
        expect(result, isNotNull);
        expect(result!, isEmpty);
      }
    });

    test('fetchSpellCheckSuggestions detects misspelled words', () async {
      if (service == null) {
        expect(service, isNull, reason: 'Backend unavailable on this platform.');
      } else {
        final List<SuggestionSpan>? result = await service.fetchSpellCheckSuggestions(
          const Locale('en', 'US'),
          'hello wrld',
        );
        expect(result, isA<List<SuggestionSpan>>());
        expect(result, isNotNull);
        expect(result!, isNotEmpty);
        expect(result.first, isA<SuggestionSpan>());
        expect(result.first.suggestions, isNotEmpty);
      }
    });

    test('fetchSpellCheckSuggestions returns an empty list for empty text', () async {
      if (service == null) {
        expect(service, isNull, reason: 'Backend unavailable on this platform.');
      } else {
        final List<SuggestionSpan>? result = await service.fetchSpellCheckSuggestions(const Locale('en', 'US'), '');
        expect(result, isA<List<SuggestionSpan>>());
        expect(result, isNotNull);
        expect(result!, isEmpty);
      }
    });
  });

  group('NativeSpellChecker.resolvedLanguageTag', () {
    test('returns null on Android; non-null BCP-47 on Windows; nullable on Linux', () async {
      final tag = await NativeSpellChecker.resolvedLanguageTag();
      if (Platform.isAndroid) {
        expect(tag, isNull, reason: 'Android defers to DefaultSpellCheckService.');
      } else if (Platform.isWindows) {
        // No-locale resolution returns the system default (the same value
        // GetUserDefaultLocaleName reports). Platform.localeName is NOT a
        // reliable anchor because `flutter test` overrides it to 'en_US' in
        // its sandbox; assert shape instead and rely on the dedicated Windows
        // live test (windows_spell_check_test.dart) for the exact comparison.
        expect(tag, isNotNull, reason: 'System-default + en-US fallback chain is never null.');
        expect(
          tag,
          matches(RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8})?(-[A-Za-z0-9]{2,8})?$')),
          reason: 'WinRT GetUserDefaultLocaleName returns a BCP-47-like tag.',
        );
      } else if (Platform.isLinux) {
        expect(tag == null || tag.isNotEmpty, isTrue, reason: 'No dict installed → null; else a non-empty tag.');
      }
    });

    test('explicit en-US: null on Android; non-null BCP-47 on Windows; nullable on Linux', () async {
      final tag = await NativeSpellChecker.resolvedLanguageTag(locale: const Locale('en', 'US'));
      if (Platform.isAndroid) {
        expect(tag, isNull);
      } else if (Platform.isWindows) {
        // en-US may or may not be installed on the host Windows: either the
        // exact tag "en-US" (supported) or the system-default fallback. Both
        // are non-null BCP-47 tags; assert the shape, not the exact value.
        expect(tag, isNotNull, reason: 'Windows fallback chain never yields null.');
        expect(tag, matches(RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8})?(-[A-Za-z0-9]{2,8})?$')));
      } else if (Platform.isLinux) {
        expect(
          tag == null || tag == 'en_US' || tag == 'en',
          isTrue,
          reason: 'Linux en-US resolution depends on hunspell-en-us being installed.',
        );
      }
    });

    test('repeated calls with the same locale are stable', () async {
      final first = await NativeSpellChecker.resolvedLanguageTag(locale: const Locale('en', 'US'));
      final second = await NativeSpellChecker.resolvedLanguageTag(locale: const Locale('en', 'US'));
      expect(second, first);
    });

    test('an unsupported locale is null on Android/Linux, non-null on Windows (fallback)', () async {
      final tag = await NativeSpellChecker.resolvedLanguageTag(locale: const Locale('zz', 'ZZ'));
      if (Platform.isAndroid) {
        expect(tag, isNull);
      } else if (Platform.isWindows) {
        expect(tag, isNotNull, reason: 'Windows fallback chain (system default → en-US) never yields null.');
      } else if (Platform.isLinux) {
        expect(tag, isNull, reason: 'No Hunspell dictionary for the zz/zz family anywhere.');
      }
    });
  });
}
