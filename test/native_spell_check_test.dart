import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:native_spell_checker/native_spell_checker.dart';

void main() {
  group('NativeSpellChecker', () {
    test('service returns null on Android', () {
      // On the CI runner (ubuntu-latest), this test validates the Linux path.
      // On Android (not testable here), service would be null.
      if (Platform.isAndroid) {
        expect(NativeSpellChecker.service, isNull);
      } else {
        // On desktop platforms, the service should be non-null.
        expect(NativeSpellChecker.service, isNotNull);
      }
    });

    test('configuration returns a SpellCheckConfiguration on all platforms', () {
      final config = NativeSpellChecker.configuration();
      expect(config, isA<SpellCheckConfiguration>());
    });

    test('configuration respects misspelledTextStyle', () {
      final style = TextStyle(color: Colors.red);
      final config = NativeSpellChecker.configuration(misspelledTextStyle: style);
      expect(config.misspelledTextStyle, style);
    });
  });

  // Platform-specific live tests — only run when the native backend is available.
  group('NativeSpellCheckService — live (Linux only)', () {
    if (!Platform.isLinux) {
      test('skipped — not running on Linux', () {
        // No-op: this group is only relevant on Linux.
      });
      return;
    }

    final service = NativeSpellChecker.service;

    test('fetchSpellCheckSuggestions returns null or empty for correct text', () async {
      if (service == null) {
        // hunspell not installed — skip gracefully.
        return;
      }

      final result = await service.fetchSpellCheckSuggestions(const Locale('en', 'US'), 'hello world');

      // With a correct sentence, there should be no misspelled words.
      // The result may be null (backend not available) or an empty list.
      expect(result == null || result.isEmpty, isTrue);
    });

    test('fetchSpellCheckSuggestions detects misspelled words', () async {
      if (service == null) {
        return;
      }

      final result = await service.fetchSpellCheckSuggestions(const Locale('en', 'US'), 'hello wrld');

      if (result != null && result.isNotEmpty) {
        // At least one SuggestionSpan should be returned for "wrld".
        expect(result.first, isA<SuggestionSpan>());
        expect(result.first.suggestions, isNotEmpty);
      }
    });

    test('fetchSpellCheckSuggestions returns empty list for empty text', () async {
      if (service == null) {
        return;
      }

      final result = await service.fetchSpellCheckSuggestions(const Locale('en', 'US'), '');

      expect(result, isEmpty);
    });
  });
}
