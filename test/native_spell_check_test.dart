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
      final SpellCheckConfiguration config =
          NativeSpellChecker.configuration(misspelledTextStyle: style);
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
        final List<SuggestionSpan>? result =
            await service.fetchSpellCheckSuggestions(const Locale('en', 'US'), 'hello world');
        expect(result, isA<List<SuggestionSpan>>());
        expect(result, isNotNull);
        expect(result!, isEmpty);
      }
    });

    test('fetchSpellCheckSuggestions detects misspelled words', () async {
      if (service == null) {
        expect(service, isNull, reason: 'Backend unavailable on this platform.');
      } else {
        final List<SuggestionSpan>? result =
            await service.fetchSpellCheckSuggestions(const Locale('en', 'US'), 'hello wrld');
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
        final List<SuggestionSpan>? result =
            await service.fetchSpellCheckSuggestions(const Locale('en', 'US'), '');
        expect(result, isA<List<SuggestionSpan>>());
        expect(result, isNotNull);
        expect(result!, isEmpty);
      }
    });
  });
}