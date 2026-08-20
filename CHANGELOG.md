# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.4.2

### Changed

- Removed the pub.dev badge images from `README.md` and `README_FR.md`
  — they kept regenerating stale pub stats and cluttered the top of the
  docs. No content lost.
- Added analyzer `exclude` entries for the generated platform folders
  (`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`) in both
  `analysis_options.yaml` and `example/analysis_options.yaml`, so the
  linter no longer analyzes the generated native scaffolding.
- Aligned the example app's Android build tooling to a mutually
  compatible set: Gradle 9.6.1 → 9.3.1, Android Gradle Plugin 9.3.1 →
  9.1.0, Kotlin 2.3.10 → 2.4.0; dropped the now-unneeded
  `android.sync.suppressAgpWarnings` flag in
  `example/android/gradle.properties`.

No API or behavior change for consumers.

## 0.4.1

### Changed

- Shortened `pubspec.yaml` `description` to comply with pub.dev's 60–180
  character limit (was ~230 characters, which penalized the package score).
  No API or behavior change.

## 0.4.0

### Added

- `NativeSpellChecker.contextMenuBuilder` — static method that builds a
  context menu with spelling suggestions inserted above the standard
  Cut/Copy/Paste/Select All buttons. Clicking a suggestion replaces the
  misspelled word and repositions the caret.
- `NativeSpellCheckService.findSuggestionSpanAt(String text, int offset)` —
  synchronous lookup into the last spell-check result cache. Returns the
  `SuggestionSpan` covering `offset`, or `null` when the cache is stale (text
  changed since the last `fetchSpellCheckSuggestions` call). Designed for
  use inside a `contextMenuBuilder`, which must be synchronous.
- `SpellCheckTextField` — drop-in `TextField` replacement that pre-wires
  spell checking, context menu suggestions, and right-click cursor
  positioning. On desktop (Windows, Linux), a `Listener` intercepts the
  secondary button (right-click), moves the caret to the text position
  under the cursor via `RenderEditable.getPositionForPoint`, then lets
  Flutter open the context menu — so suggestions appear for the
  right-clicked word without requiring a prior left-click selection.
  On Android, behaves as a plain `TextField` (the OS handles everything
  natively).
- `SpellCheckTextFormField` — drop-in `TextFormField` replacement with
  the same spell-check and right-click wiring as `SpellCheckTextField`,
  plus form-specific params (`validator`, `onFieldSubmitted`, `onSaved`,
  `initialValue`, `autovalidateMode`).
- `SpellCheckTextMixin` — shared logic used by both widgets, so the
  desktop right-click caret placement and spell-check wiring live in one
  place.
- `NativeSpellChecker.defaultMisspelledTextStyle` — public constant so
  consumers can reuse the plugin's default red wavy underline style.
- Both `SpellCheckTextField` and `SpellCheckTextFormField` accept
  `misspelledTextStyle` and `misspelledSelectionColor` params to customize
  the spell-check visual style.

### Changed

- `NativeSpellCheckService.fetchSpellCheckSuggestions` is now `async` and
  caches the last result (`_lastText` / `_lastSpans`) so
  `findSuggestionSpanAt` can serve the context menu synchronously without
  triggering a new OS spell check.
- Repository flattened to a single-package layout: the plugin now lives at
  the repository root instead of under `packages/native_spell_checker/`. The
  Dart pub workspace was removed (no longer needed with a single package),
  the `repository` URL simplified, a `.pubignore` excludes repo-only tooling
  (`_script/`, `githooks/`) from the published archive, and `docs/` was
  renamed to `doc/` to follow the Pub layout convention. No API or behavior
  change for consumers.

## 0.3.0

### Added

- `NativeSpellChecker.resolvedLanguageTag({Locale? locale})` — returns the
  language tag of the dictionary the OS spell checker will **actually** use
  for the given locale (or the platform default locale when `locale` is
  `null`), after applying the same fallback chain used during spell
  checking.
  - **Windows**: BCP-47 tag (e.g. `fr-FR`, `en-US`), resolved via
    `ISpellCheckerFactory.isSupported` on a worker `Isolate` (MTA, same
    rationale as spell checking — COM must not touch the STA UI thread).
  - **Linux**: Hunspell dictionary name (e.g. `fr_FR`, `en_US`) of the first
    `.aff`/`.dic` pair found in `/usr/share/hunspell/`. Returns `null` if no
    dictionary is installed for the locale family.
  - **Android**: always `null` — Flutter's `DefaultSpellCheckService` owns
    spell checking; use `Platform.localeName` for the system locale.
- Internal `NativeSpellCheckBackend` interface so `NativeSpellCheckService`
  can delegate to platform methods (such as `resolvedLanguageTag`) without an
  `is`/cast per platform.
- Example app now displays a "Native language" line sourcing
  `NativeSpellChecker.resolvedLanguageTag()` on desktop (and
  `Platform.localeName` on Android).
- Live tests for `resolvedLanguageTag` on Windows: cross-consistency with
  `fetchSpellCheckSuggestions` (same `_resolveLanguageTag` code path),
  fallback for unsupported locales, stability across isolates, and concurrent
  interleaving with spell checking.

### Fixed

- Example: platform detection was broken. The previous implementation relied
  on `service.toString().contains('Windows'|'Linux')`, but the default
  `toString()` returns `Instance of 'NativeSpellCheckService'` (no override),
  so the UI always showed "Unknown platform" on Windows and Linux. The
  example now uses `dart:io`'s `Platform.isWindows` / `Platform.isLinux` /
  `Platform.isAndroid` and displays the resolved native language tag.
- Example: `example/test/widget_test.dart` was an unmodified Flutter template
  referencing a non-existent `MyApp` class (compilation failure). Replaced
  with a real widget test exercising the platform-backend label and the
  resolved native language (escaped from `FakeAsync` via `tester.runAsync`
  so the Windows COM `Isolate.run` can complete during the test).

### Changed

- `WindowsSpellCheckService` and `LinuxSpellCheckService` now
  `extends NativeSpellCheckBackend` instead of `SpellCheckService` (no
  observable API change; they still satisfy `SpellCheckService`).
- `WindowsSpellCheckService._resolveLanguageTag` now accepts `Locale?`:
  a `null` locale skips the requested-locale step and resolves straight to
  the system default (`GetUserDefaultLocaleName`), i.e. the language the spell
  checker would select on its own.
- `LinuxSpellCheckService._ensureDictionary` refactored to share
  `_resolveDictionaryTag` with `resolvedLanguageTag`, so the reported tag and
  the actually-loaded dictionary are guaranteed to agree.

## 0.2.0

### Fixed

- **Windows spell check now actually works.** The COM call was previously
  silently failing: the UI thread is initialized as STA by the Flutter
  Windows runner, but the plugin called `CoInitializeEx(COINIT_MULTITHREADED)`,
  causing `RPC_E_CHANGED_MODE` (0x80010106) to be thrown and swallowed
  (`return null`). No suggestions, no underlines, no crash — just silence.
- Tolerate `RPC_E_CHANGED_MODE` when the thread is already initialized with a
  different apartment. WinRT `ISpellChecker2` objects are agile and work in
  either STA or MTA, so the existing apartment wins.
- Eliminate UI jank on Windows. A single `comprehensiveCheck` call takes
  ~200 ms — previously executed synchronously on the UI thread (12x the 60 fps
  frame budget), causing visible stutter at every keystroke. The whole COM work
  is now delegated to a worker `Isolate` via `Isolate.run`, leaving the UI
  thread free.
- Memoize `NativeSpellCheckService.instance` (lazy singleton). Previously, a
  brand-new `WindowsSpellCheckService` was constructed on every `service` access,
  re-initializing COM and re-creating the spell checker on each call.
- `configuration()` now provides a default `misspelledTextStyle` (red wavy
  underline, matching Material's `materialMisspelledTextStyle`) when none is
  provided. Required by `EditableText` in debug mode
  (`assert spellCheckConfiguration.misspelledTextStyle != null`) and would
  crash in release mode on the first spell-check result otherwise. Safe for
  non-Material consumers too.

### Changed

- Surface COM exceptions via `debugPrint` before returning `null`. Failures
  are no longer silent — they appear in the console and Flutter DevTools.
- Refactor `WindowsSpellCheckService` internals to `static` methods so the
  COM-bound computation can cross the `Isolate` boundary without capturing
  `this`. The per-Isolate COM init flag is now a static field.

## 0.1.0

- Initial release.
- Windows support via WinRT `ISpellChecker2` (COM FFI through `win32` package).
- Linux support via `libhunspell-1.7` system library (dart:ffi).
- Android defers to Flutter's built-in `DefaultSpellCheckService`.
- Zero bundled dictionaries — uses OS-installed spell checkers.