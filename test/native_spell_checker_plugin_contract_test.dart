// Contrat dartPluginClass — filet de sécurité contre les régressions
// de signature `registerWith()` qui n'éclatent qu'à `flutter build windows`.
//
// Flutter génère automatiquement
// `.dart_tool/flutter_build/dart_plugin_registrant.dart` qui appelle, pour
// chaque `dartPluginClass` déclaré dans pubspec.yaml :
//
//     NativeSpellChecker.registerWith();   // 0 argument
//
// Si la signature exige un paramètre positionnel requis
// (ex: `registerWith(Object? binding)`), le build MSBuild échoue avec :
//     Too few positional arguments: 1 required, 0 given
//
// Les tests ci-dessous reproduisent fidèlement l'appel à zéro argument. En
// cas de régression de signature, le **compilateur** refuse la compilation
// du fichier de test avec le message exact que produirait MSBuild — l'erreur
// est donc remontée au niveau `flutter test` (et `dart analyze`) AVANT le
// build Windows, sans attendre la chaîne MSBuild/CMake.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_spell_checker/native_spell_checker.dart';
import 'package:yaml/yaml.dart';

/// Charge `pubspec.yaml` et renvoie {plateforme -> dartPluginClass}
/// pour chaque plateforme déclarant un `dartPluginClass`.
Map<String, String> _dartPluginClassesFromPubspec() {
  final file = File('pubspec.yaml');
  final content = file.readAsStringSync();
  final yamlDoc = loadYaml(content) as YamlMap;
  final flutter = yamlDoc['flutter'];
  if (flutter is! YamlMap) {
    return <String, String>{};
  }
  final plugin = flutter['plugin'];
  if (plugin is! YamlMap) {
    return <String, String>{};
  }
  final platforms = plugin['platforms'];
  if (platforms is! YamlMap) {
    return <String, String>{};
  }

  final result = <String, String>{};
  for (final entry in platforms.entries) {
    final platform = entry.key as String;
    final platformData = entry.value as YamlMap;
    final dartPluginClass = platformData['dartPluginClass'];
    if (dartPluginClass is String) {
      result[platform] = dartPluginClass;
    }
  }
  return result;
}

void main() {
  final dartPluginClasses = _dartPluginClassesFromPubspec();

  group('A. Cohérence pubspec.yaml <-> symboles source', () {
    test('au moins une plateforme déclare dartPluginClass', () {
      expect(
        dartPluginClasses,
        isNotEmpty,
        reason: 'Aucun `dartPluginClass` déclaré dans pubspec.yaml — '
            'le plugin ne sera pas enregistré par Flutter au build.',
      );
    });

    for (final entry in dartPluginClasses.entries) {
      final platform = entry.key;
      final className = entry.value;

      test("pubspec déclare `$className` pour `$platform`, exporté par le plugin", () {
        // Vérifie que le nom déclaré dans pubspec.yaml correspond exactement
        // au symbole exporté par `lib/native_spell_checker.dart`. Toute
        // incohérence (typo, renommage unilatéral de la classe) fait échouer
        // ce test avec un message explicite — bien avant le build desktop.
        expect(
          className,
          'NativeSpellChecker',
          reason: 'pubspec.yaml déclare `dartPluginClass: $className` pour la '
              "plateforme `$platform`, mais le symbole exporté par le plugin est "
              "'NativeSpellChecker'. Les deux doivent correspondre exactement.",
        );
      });
    }
  });

  group('B. Contrat registerWith() du dartPluginClass', () {
    // Test pivot : reproduit l'appel exact de `dart_plugin_registrant.dart`.
    // Si la signature exigeait à nouveau un paramètre positionnel requis
    // (ex: `registerWith(Object? binding)`), ce test ne compilerait pas —
    // le compilateur Dart produirait le message identique à MSBuild :
    //     Too few positional arguments: 1 required, 0 given.
    // C'est le filet de sécurité statique attendu.
    test('NativeSpellChecker.registerWith() est appelable à 0 argument', () {
      NativeSpellChecker.registerWith();
    });

    test('registerWith() est idempotente et ne lève jamais', () {
      NativeSpellChecker.registerWith();
      NativeSpellChecker.registerWith();
      NativeSpellChecker.registerWith();
    });

    test('registerWith() ne mute pas NativeSpellChecker.service (singleton stable)', () {
      final before = NativeSpellChecker.service;
      NativeSpellChecker.registerWith();
      final after = NativeSpellChecker.service;
      expect(after, same(before));
    });
  });
}