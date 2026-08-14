# native_spell_checker

[![pub package](https://img.shields.io/pub/v/native_spell_checker.svg)](https://pub.dev/packages/native_spell_checker)
[![likes](https://img.shields.io/pub/likes/native_spell_checker?logo=dart)](https://pub.dev/packages/native_spell_checker/score)
[![pub points](https://img.shields.io/pub/points/native_spell_checker?logo=dart)](https://pub.dev/packages/native_spell_checker/score)

A Flutter plugin for native OS spell checking on desktop (Windows, Linux) — zero bundled dictionaries, uses the operating system's built-in spell checker.

## Features

- **Windows**: Uses WinRT `ISpellChecker2` (COM API) via the [`win32`](https://pub.dev/packages/win32) package.
- **Linux**: Uses `libhunspell-1.7` system library via `dart:ffi`. Dictionaries are read from `/usr/share/hunspell/`.
- **Android**: Defers to Flutter's built-in `DefaultSpellCheckService` (no code needed).
- **Zero bundled dictionaries** — the OS provides everything.
- **Multi-language** — automatically uses the OS-installed dictionaries for the current locale.
- **100% offline** — no cloud APIs, no network calls.

## Getting started

Add the dependency:

```yaml
dependencies:
  native_spell_checker: ^0.1.0
```

### Linux prerequisite

The `libhunspell-1.7-0` package must be installed on the target system. On Debian/Ubuntu:

```bash
sudo apt-get install libhunspell-1.7-0 hunspell-fr hunspell-en-us
```

Dictionaries are provided by `hunspell-*` packages and stored in `/usr/share/hunspell/`.

## Usage

```dart
import 'package:native_spell_checker/native_spell_checker.dart';

TextField(
  spellCheckConfiguration: NativeSpellChecker.configuration(),
)
```

Or use the service directly:

```dart
final service = NativeSpellChecker.service;
final suggestions = await service?.fetchSpellCheckSuggestions(
  Locale('fr', 'FR'),
  'Hello wrld',
);
```

On Android, `NativeSpellChecker.service` returns `null` — Flutter automatically uses `DefaultSpellCheckService`.

### Discover the language the spell checker will use

```dart
// null locale → resolve from the OS default locale.
final tag = await NativeSpellChecker.resolvedLanguageTag();
print('Native spell check language: $tag'); // e.g. "fr-FR" / "fr_FR"

// explicit locale → same fallback chain used during spell checking.
final enTag = await NativeSpellChecker.resolvedLanguageTag(locale: const Locale('en', 'US'));
```

Returns `null` on Android (where the plugin defers to Flutter). Use
`Platform.localeName` to read the system locale on Android.

## How it works

| Platform | Backend | Dictionary source | Language tag format |
|---|---|---|---|
| Android | Flutter `DefaultSpellCheckService` | OS (TextServicesManager) | `null` (use `Platform.localeName`) |
| Windows | WinRT `ISpellChecker2` (COM FFI) | OS (Windows SpellChecker) | BCP-47 (`fr-FR`, `en-US`) |
| Linux | `libhunspell-1.7` (dart:ffi) | `/usr/share/hunspell/` | Hunspell (`fr_FR`, `en_US`) |

## License

MIT