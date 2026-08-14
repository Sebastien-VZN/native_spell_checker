# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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