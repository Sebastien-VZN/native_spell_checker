// Integration widget test for the example app.

import 'dart:io' show Platform;

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_spell_checker/native_spell_checker.dart';

void main() {
  // Verifies the two things the example app is supposed to surface:
  //   1. the platform backend label (the bug being fixed: the previous
  //      `service.toString().contains(...)` heuristic always fell through to
  //      "Unknown platform"; we now assert the correct per-platform label),
  //   2. the native language value resolved from the OS spell checker.
  //
  // This is a *live* test on the host platform: on Windows it actually spawns
  // the worker Isolate + COM SpellCheckerFactory to resolve the language tag,
  // exactly the code path shipped in `example/lib/main.dart`.
  testWidgets('example displays the correct platform backend label', (
    tester,
  ) async {
    await tester.pumpWidget(const NativeSpellCheckerExampleApp());

    expect(
      find.text('native_spell_checker'),
      findsOneWidget,
      reason: 'AppBar title.',
    );
    expect(find.text('Platform backend'), findsOneWidget);

    final expectedBackend = Platform.isWindows
        ? 'Windows — using WinRT ISpellChecker2'
        : Platform.isLinux
        ? 'Linux — using libhunspell-1.7'
        : Platform.isAndroid
        ? 'Android — using Flutter DefaultSpellCheckService'
        : 'Unknown platform';
    expect(
      find.text(expectedBackend),
      findsOneWidget,
      reason:
          'The example must show the backend for the host platform, '
          'not the old "Unknown platform" fallback.',
    );
  });

  testWidgets('example resolves and displays the native language', (
    tester,
  ) async {
    await tester.pumpWidget(const NativeSpellCheckerExampleApp());

    expect(find.text('Native language'), findsOneWidget);

    // The example's `_updatePlatformInfo` awaits `NativeSpellChecker.
    // resolvedLanguageTag()`, which on Windows spawns a worker Isolate (MTA)
    // running real COM — this never completes under `testWidgets`' default
    // `FakeAsync`. `tester.runAsync` escapes the fake clock so the real
    // async (Isolate + COM) can actually run; afterwards `pumpAndSettle`
    // flushes the example's setState rebuild.
    await tester.runAsync(() async {
      // Mirror the exact async the example performs, plus a microtask drain.
      await NativeSpellChecker.resolvedLanguageTag();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    // Once settled, the loading placeholder must be gone and a real value shown.
    final valueFinder = find.byKey(const ValueKey('nativeLanguageValue'));
    expect(valueFinder, findsOneWidget);
    final value = tester.widget<Text>(valueFinder).data ?? '';

    expect(
      value,
      isNotEmpty,
      reason: 'Native language value must be displayed.',
    );
    expect(
      value,
      isNot('(loading...)'),
      reason:
          'After settle, the resolved language must replace the loading placeholder.',
    );
    if (Platform.isAndroid) {
      expect(
        value,
        Platform.localeName,
        reason:
            'Android surfaces the system locale (Flutter owns spell checking).',
      );
    } else {
      // Desktop backends resolve a BCP-47 / Hunspell tag, or "(no dictionary
      // available)" on Linux when no dict is installed; never "(unsupported)".
      expect(
        value,
        isNot('(unsupported)'),
        reason:
            'Desktop backends must resolve a value or a "(no dictionary available)" fallback.',
      );
    }
  });
}
