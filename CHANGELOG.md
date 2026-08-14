# Changelog

## 0.1.0

- Initial release.
- Windows support via WinRT `ISpellChecker2` (COM FFI through `win32` package).
- Linux support via `libhunspell-1.7` system library (dart:ffi).
- Android defers to Flutter's built-in `DefaultSpellCheckService`.
- Zero bundled dictionaries — uses OS-installed spell checkers.