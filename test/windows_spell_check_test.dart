import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:native_spell_checker/native_spell_checker.dart';

void main() {
  if (Platform.isWindows) {
    group('WindowsSpellCheckService — live', () {
      test('fetchSpellCheckSuggestions returns non-empty suggestions for a misspelled word', () async {
        final service = NativeSpellChecker.service;
        expect(service, isNotNull, reason: 'WindowsSpellCheckService must be available on Windows.');
        final List<SuggestionSpan>? result =
            await service!.fetchSpellCheckSuggestions(const Locale('en', 'US'), 'hello wrld');
        expect(result, isA<List<SuggestionSpan>>());
        expect(result, isNotNull);
        expect(result!, isNotEmpty);
        expect(result.first, isA<SuggestionSpan>());
        expect(result.first.suggestions, isNotEmpty);
      });

      test('fetchSpellCheckSuggestions returns an empty list for correct text', () async {
        final service = NativeSpellChecker.service;
        expect(service, isNotNull);
        final List<SuggestionSpan>? result =
            await service!.fetchSpellCheckSuggestions(const Locale('en', 'US'), 'hello world');
        expect(result, isA<List<SuggestionSpan>>());
        expect(result, isNotNull);
        expect(result!, isEmpty);
      });

      test('repeated calls stay consistent (COM apartment does not break)', () async {
        final service = NativeSpellChecker.service;
        expect(service, isNotNull);
        for (var i = 0; i < 3; i++) {
          final List<SuggestionSpan>? result =
              await service!.fetchSpellCheckSuggestions(const Locale('en', 'US'), 'wrld');
          expect(result, isNotNull);
          expect(result!, isNotEmpty);
        }
      });
    });
  } else {
    test('Windows-only test file does not run assertions on non-Windows platforms', () {
      expect(Platform.isWindows, isFalse);
    });
  }
}