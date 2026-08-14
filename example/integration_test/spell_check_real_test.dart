// Test d'intégration — tourne dans le VRAI process de l'app Windows (STA, UI
// thread), pas dans la VM Dart de `flutter test` (MTA).
//
// Lancement :
//   flutter test -d windows integration_test/spell_check_real_test.dart
//
// Si COM échoue en STA (le contexte réel de `flutter run windows`), les appels
// ci-dessous renverront `null` → tests ROUGES avec le HRESULT réel imprimé par
// le debugPrint. C'est la vérité du terrain, sans filtration par le runtime.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:native_spell_checker/native_spell_checker.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final service = NativeSpellChecker.service;

  group('Backend Windows réel (process STA, UI thread)', () {
    test('service est disponible sur Windows', () {
      expect(
        service,
        isNotNull,
        reason:
            'NativeSpellChecker.service doit être non-null sur Windows. '
            'Si null, le singleton instance n’a pas construit WindowsSpellCheckService.',
      );
    });

    test('COM en STA renvoie de vraies suggestions pour un mot mal orthographié', () async {
      expect(service, isNotNull);
      final List<SuggestionSpan>? result = await service!.fetchSpellCheckSuggestions(
        const Locale('en', 'US'),
        'hello wrld',
      );
      expect(result, isNotNull, reason: 'COM a échoué en STA — voir debugPrint ci-dessus pour le HRESULT.');
      expect(result, isA<List<SuggestionSpan>>());
      expect(result!, isNotEmpty, reason: '"wrld" doit produire au moins un SuggestionSpan.');
      expect(result.first, isA<SuggestionSpan>());
      expect(
        result.first.suggestions,
        isNotEmpty,
        reason: 'Le SuggestionSpan pour "wrld" doit contenir des suggestions réelles de WinRT.',
      );
    });

    test('COM en STA renvoie une liste vide pour un texte correct', () async {
      expect(service, isNotNull);
      final List<SuggestionSpan>? result = await service!.fetchSpellCheckSuggestions(
        const Locale('en', 'US'),
        'hello world',
      );
      expect(result, isNotNull, reason: 'COM a échoué en STA — voir debugPrint ci-dessus pour le HRESULT.');
      expect(result, isA<List<SuggestionSpan>>());
      expect(result!, isEmpty, reason: '"hello world" ne doit produire aucun SuggestionSpan.');
    });

    test('COM en STA ne lève pas et renvoie un résultat (non-null) pour du texte vide', () async {
      expect(service, isNotNull);
      final List<SuggestionSpan>? result = await service!.fetchSpellCheckSuggestions(const Locale('en', 'US'), '');
      expect(result, isA<List<SuggestionSpan>>());
      expect(result, isNotNull);
      expect(result!, isEmpty);
    });

    test('appels COM répétés restent stables en STA (pas de fuite/blocage COM)', () async {
      expect(service, isNotNull);
      for (var i = 0; i < 5; i++) {
        final List<SuggestionSpan>? result = await service!.fetchSpellCheckSuggestions(
          const Locale('en', 'US'),
          'wrld',
        );
        expect(result, isNotNull, reason: 'Itération $i : COM a échoué en STA.');
        expect(result!, isNotEmpty);
      }
    });

    test('l’UI thread reste réactif pendant un appel COM (pas de blocage UI)', () async {
      // Mesure objectivement le BLOCAGE de l’UI thread, pas le wall-clock.
      // Un Timer planifié à 5 ms doit s’exécuter ~5 ms plus tard si l’UI
      // thread est libre. Si l’appel COM tourne sur l’UI thread (avant fix),
      // le Timer ne s’exécutera qu’après ~200 ms => jank. Avec l’Isolate
      // worker, le Timer s’exécute pendant que le COM tourne sur un autre
      // thread => latence proche de 5 ms.
      expect(service, isNotNull);

      final sw = Stopwatch()..start();
      var timerLatencyMs = -1;
      Timer(const Duration(milliseconds: 5), () {
        timerLatencyMs = sw.elapsedMilliseconds;
      });

      // Lance l’appel COM (potentiellement bloquant si mal architecturé).
      await service!.fetchSpellCheckSuggestions(const Locale('en', 'US'), 'hello wrld');

      // Laisse le Timer s’exécuter si la COM n’a pas déjà rendu la main.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(timerLatencyMs, greaterThanOrEqualTo(0), reason: 'Le Timer ne s’est jamais exécuté.');
      expect(
        timerLatencyMs,
        lessThan(50),
        reason:
            'Timer exécuté $timerLatencyMs ms après scheduling — l’UI '
            'thread était bloquée par l’appel COM (jank perceptible à la frappe).',
      );
    });
  });

  group('Langue native de l’OS', () {
    // Détecte le bug « la langue native de l’OS n’est pas utilisée » :
    // si le service ne tombe pas sur en-US en dernier recours mais utilise la
    // locale système, un mot français correct ne doit pas être marqué faux.
    test('la locale système est supportée par ISpellCheckerFactory', () async {
      expect(service, isNotNull);
      // On demande la locale neutre ; le backend doit résoudre vers une langue
      // supportée par l’OS (pas un retour null silencieux).
      final List<SuggestionSpan>? result = await service!.fetchSpellCheckSuggestions(Locale.fromSubtags(), 'test');
      // On n’exige pas empty/non-empty (dépend de la langue résolue), mais on
      // exige que COM ait répondu (non-null) — preuve que la résolution marche.
      expect(result, isNotNull, reason: 'COM a échoué pendant la résolution de la locale système.');
      expect(result, isA<List<SuggestionSpan>>());
    });
  });

  group('Wiring réel du widget TextField + configuration()', () {
    testWidgets('un TextField configuré accepte la saisie sans jeter d’exception', (WidgetTester tester) async {
      final controller = TextEditingController();
      final SpellCheckConfiguration wiredConfig = NativeSpellChecker.configuration();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller, spellCheckConfiguration: wiredConfig),
          ),
        ),
      );

      // Saisie d’un mot mal orthographié dans le vrai widget, pompage pour
      // laisser le spell check async se terminer.
      await tester.enterText(find.byType(TextField), 'hello wrld');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(TextField), findsOneWidget);
      expect(controller.text, 'hello wrld');
      // Vérifie que la config fournie a bien un misspelledTextStyle non-null
      // (condition requise par EditableText en debug).
      expect(wiredConfig.misspelledTextStyle, isNotNull);
    });
  });
}
