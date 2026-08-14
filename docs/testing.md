# Testing — native_spell_checker

## Overview

Three test files, each with a distinct purpose:

| File | Scope | Platform | Runs in CI |
|---|---|---|---|
| `native_spell_check_test.dart` | Unit + live (cross-platform) | All | Yes (ubuntu) |
| `windows_spell_check_test.dart` | Live (Windows COM) | Windows only | No (CI is ubuntu) |
| `native_spell_checker_plugin_contract_test.dart` | Static contract | All | Yes |

## test/native_spell_check_test.dart

Cross-platform tests that run on any platform. Two groups:

### Unit tests (no native backend needed)

- `service is null on Android, non-null on desktop` — validates the dispatch
  logic in `NativeSpellCheckService.instance`
- `configuration returns a SpellCheckConfiguration on all platforms` —
  ensures `configuration()` never throws
- `configuration respects the provided misspelledTextStyle` — custom style
  passes through
- `configuration provides a default misspelledTextStyle on desktop` —
  the default red wavy underline is set when none is provided (required by
  `EditableText` in debug mode)
- `service is memoized across calls` — singleton stability

### Live tests (require native backend)

- `fetchSpellCheckSuggestions returns an empty list for correct text` —
  "hello world" → no errors
- `fetchSpellCheckSuggestions detects misspelled words` — "hello wrld" →
  non-empty `SuggestionSpan` with suggestions
- `fetchSpellCheckSuggestions returns an empty list for empty text` —
  edge case
- `resolvedLanguageTag` — shape validation, stability, fallback for
  unsupported locales

On Android, live tests assert `service == null` (backend unavailable) and
skip the native calls.

## test/windows_spell_check_test.dart

Windows-only live tests. Completely skipped on non-Windows platforms
(`else` branch asserts `Platform.isWindows == false`).

Tests validate the real WinRT COM integration:

- **Spell checking**: "wrld" → suggestions, "hello world" → empty
- **COM stability**: 3 repeated calls don't break the apartment
- **Language resolution**: `resolvedLanguageTag()` with no locale matches
  `GetUserDefaultLocaleName()` (called directly via win32, not
  `Platform.localeName` which returns a sandbox default under `flutter test`)
- **Round-trip**: system-default locale requested explicitly returns the same
  tag
- **Fallback**: unsupported locale (`zz_ZZ`) → non-null (system default or
  en-US)
- **Cross-consistency**: `resolvedLanguageTag` returns the same dictionary
  that `fetchSpellCheckSuggestions` will use
- **Concurrency**: interleaved `resolvedLanguageTag` + `fetchSpellCheckSuggestions`
  on concurrent isolates don't corrupt COM state

These tests only run on a Windows host (developer machine or Windows CI runner).
The GitHub Actions CI runs on ubuntu-latest, so these tests are skipped in CI.

## test/native_spell_checker_plugin_contract_test.dart

Static contract test — a safety net against `registerWith()` signature
regressions.

### The problem it prevents

Flutter generates `.dart_tool/flutter_build/dart_plugin_registrant.dart`
which calls `NativeSpellChecker.registerWith()` with zero arguments. If the
signature requires a positional parameter (e.g. `registerWith(Object? binding)`),
the build fails at MSBuild time with:

```
Too few positional arguments: 1 required, 0 given
```

This error only surfaces during `flutter build windows` — not during
`flutter analyze` or `flutter test` on Linux.

### How the test catches it

The test file calls `NativeSpellChecker.registerWith()` with zero arguments.
If the signature regresses, the **compiler** rejects the test file with the
exact same error MSBuild would produce. The failure surfaces at `flutter test`
and `dart analyze` — before the Windows build.

The test also validates:
- `pubspec.yaml` declares `dartPluginClass: NativeSpellChecker` for at least
  one platform
- The class name in pubspec matches the exported symbol
- `registerWith()` is idempotent (multiple calls don't throw)
- `registerWith()` doesn't mutate `NativeSpellChecker.service` (singleton
  stability)

## Running tests

```bash
# All tests (from repo root)
flutter test

# Only the cross-platform test
flutter test test/native_spell_check_test.dart

# Only the contract test
flutter test test/native_spell_checker_plugin_contract_test.dart

# Windows live tests (on a Windows host)
flutter test test/windows_spell_check_test.dart
```

## CI behavior

The GitHub Actions workflow (`validate` job) runs `flutter test` on
ubuntu-latest with `libhunspell-1.7-0`, `hunspell-en-us`, and `hunspell-fr`
installed. This means:

- `native_spell_check_test.dart` — live Linux tests run against real hunspell
- `windows_spell_check_test.dart` — skipped (not Windows)
- `native_spell_checker_plugin_contract_test.dart` — runs (static, no backend)