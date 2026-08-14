# native_spell_checker — Architecture & Principles

## What this plugin does

`native_spell_checker` provides a single `SpellCheckService` implementation that
delegates to the operating system's built-in spell checker on each platform:

| Platform | Backend | Dictionary source | Bundled? |
|---|---|---|---|
| **Windows** | WinRT `ISpellChecker2` (COM, via `win32` package) | OS SpellChecker (installed language packs) | No |
| **Linux** | `libhunspell-1.7.so.0` (dart:ffi) | `/usr/share/hunspell/` (system packages) | No |
| **Android** | Flutter `DefaultSpellCheckService` (native) | OS `TextServicesManager` | No |

Zero bundled dictionaries. The OS provides everything. 100% offline.

## Why

Flutter's `SpellCheckService` abstraction lets you plug a custom spell checker
into any `TextField` via `spellCheckConfiguration`. On Android, Flutter already
ships `DefaultSpellCheckService` (MethodChannel → Android `TextServicesManager`).
On desktop (Windows, Linux), there is **nothing** — the framework falls back to
"spell check disabled".

This plugin fills that gap by wrapping the native OS APIs:

- **Windows**: `Windows.Data.Text.SpellChecker` (WinRT COM) — the same engine
  that powers Windows Notepad, Edge, and Office. Exposed via the `win32` Dart
  package (FFI to COM interfaces, no native C++ to compile).
- **Linux**: `libhunspell-1.7` — the standard spell-checking library on Debian/
  Ubuntu. Dictionaries are `.aff`+`.dic` files installed via `apt install
  hunspell-fr`, `hunspell-en-us`, etc. The library is pre-installed on Debian 13
  (`libhunspell-1.7-0`).

## Architecture

```
NativeSpellChecker (public API)
  ├── service → NativeSpellCheckService (singleton, memoized)
  │     └── _delegate: NativeSpellCheckBackend (abstract)
  │           ├── WindowsSpellCheckService  (win32 COM, Isolate.run)
  │           └── LinuxSpellCheckService     (dart:ffi, same-thread)
  ├── configuration() → SpellCheckConfiguration (wired to service)
  └── resolvedLanguageTag() → Future<String?> (which dict the OS will use)
```

### NativeSpellCheckBackend (interface)

Abstract class extending `SpellCheckService` with one extra method:
`resolvedLanguageTag({Locale? locale})`. This lets the service expose which
dictionary the OS will actually use for a given locale — useful for UI display
and debugging. Both platform backends implement it.

### WindowsSpellCheckService

Key design decisions:

1. **Worker Isolate (MTA)**: The entire COM call runs inside `Isolate.run`.
   The Flutter Windows runner initializes the UI thread as STA. Calling
   `CoInitializeEx(COINIT_MULTITHREADED)` on the UI thread throws
   `RPC_E_CHANGED_MODE` (0x80010106). The worker isolate starts fresh (MTA),
   so COM init succeeds. WinRT `ISpellChecker2` objects are agile — they work
   in either apartment.

2. **Static methods**: Everything that runs in the isolate is `static`. The
   closure passed to `Isolate.run` cannot capture `this` (not serializable
   across isolate boundaries). Only `Locale` and `String` are captured.

3. **Tolerant COM init**: `_ensureComInit` accepts `S_FALSE` (already init,
   same apartment) and `RPC_E_CHANGED_MODE` (already init, different apartment).
   The existing apartment wins; SpellChecker is agile.

4. **Language fallback chain**: requested locale → `GetUserDefaultLocaleName`
   (system default) → `"en-US"` (hardcoded last resort). The system default is
   checked via `ISpellCheckerFactory.isSupported()` before being used.

5. **ComprehensiveCheck**: Uses `ISpellChecker2.comprehensiveCheck()` (not
   `Check()`) — it returns `IEnumSpellingError` with `startIndex`, `length`,
   `correctiveAction` (DELETE/REPLACE/GET_SUGGESTIONS), and `replacement`.
   For `GET_SUGGESTIONS`, calls `ISpellChecker.suggest()` to get `IEnumString`.

### LinuxSpellCheckService

Key design decisions:

1. **FFI direct**: `DynamicLibrary.open("libhunspell-1.7.so.0")` — no package
   dependency, no native code to compile. The `.so` is pre-installed on Debian 13.

2. **Same-thread**: Hunspell is a C library with no threading requirements.
   Unlike Windows COM, there is no apartment model to respect. Calls are
   synchronous and fast (< 1ms per word).

3. **Dictionary resolution**: Looks for `/usr/share/hunspell/{locale}.aff`
   and `.dic` files. Candidates tried in order: full locale tag (e.g.
   `fr_FR`) → language only (e.g. `fr`). First match wins.

4. **Dictionary caching**: The `Hunhandle` is created once per locale and
   reused. Changing the locale destroys the old handle and creates a new one.

5. **Word splitting**: Regex `[a-zA-ZàâæçéèêëîïôœùûüÿÀÂÆÇÉÈÊËÎÏÔŒÙÛÜŸ''-]+`
   splits text into words. Each word is checked via `Hunspell_spell()`;
   misspelled words get suggestions via `Hunspell_suggest()`.

## Public API

```dart
// Get the platform-appropriate SpellCheckService (null on Android)
final service = NativeSpellChecker.service;

// Get a SpellCheckConfiguration ready for any TextField
TextField(
  spellCheckConfiguration: NativeSpellChecker.configuration(),
)

// Discover which dictionary the OS will use
final tag = await NativeSpellChecker.resolvedLanguageTag();
// Windows: "fr-FR" (BCP-47)
// Linux: "fr_FR" (Hunspell name)
// Android: null
```

## Testing

Three test files:

### test/native_spell_check_test.dart

Cross-platform unit + live tests. Validates:
- `service` is null on Android, non-null on desktop
- `configuration()` returns a valid `SpellCheckConfiguration` with a default
  `misspelledTextStyle` on desktop (required by `EditableText` in debug mode)
- `service` is memoized (stable singleton across calls)
- Live spell checking: correct text → empty results, misspelled text → non-empty
  `SuggestionSpan` with suggestions
- `resolvedLanguageTag()`: shape validation per platform, stability across
  repeated calls, fallback for unsupported locales

### test/windows_spell_check_test.dart

Windows-only live tests (skipped on other platforms). Validates:
- `fetchSpellCheckSuggestions` returns non-empty suggestions for "wrld"
- `fetchSpellCheckSuggestions` returns empty for "hello world"
- Repeated calls stay consistent (COM apartment does not break)
- `resolvedLanguageTag()` with no locale matches `GetUserDefaultLocaleName`
  (called directly via win32, not `Platform.localeName` which is unreliable
  under `flutter test`)
- System-default locale round-trips when requested explicitly
- Unsupported locale falls back to a non-null tag
- `resolvedLanguageTag` matches the dictionary `fetchSpellCheckSuggestions`
  will use (cross-consistency)
- Interleaved `resolvedLanguageTag` + `fetchSpellCheckSuggestions` on concurrent
  isolates don't corrupt COM state

### test/native_spell_checker_plugin_contract_test.dart

Static contract test — guards against `registerWith()` signature regressions
that only surface at `flutter build windows` (MSBuild). Reproduces the exact
zero-argument call that `dart_plugin_registrant.dart` generates. If the
signature requires a positional parameter, the test file fails to compile —
the error surfaces at `flutter test` / `dart analyze` before the build.

## CI/CD

`.github/workflows/build_check.yml` — GitHub Actions on push/PR to `main`:

1. **validate** (ubuntu-latest): `dart format -l 120 --set-exit-if-changed` →
   `flutter analyze` → `flutter test` (with `libhunspell-1.7-0` + `hunspell-en-us`
   + `hunspell-fr` installed for live Linux tests)
2. **android-build**: APK from `example/`
3. **linux-build**: Linux binary from `example/` (with hunspell deps)
4. **windows-build**: Windows binary from `example/`
5. **release**: GitHub release on push to `main` (tag from `pubspec.yaml`)

## Linux prerequisites

The `libhunspell-1.7-0` package must be installed on the target system:

```bash
sudo apt-get install libhunspell-1.7-0 hunspell-fr hunspell-en-us
```

Dictionaries are provided by `hunspell-*` packages and stored in
`/usr/share/hunspell/`. The plugin reads them at runtime — no bundled assets.