# native_spell_checker — Example app

A demo app showing the plugin in action on Windows, Linux, and Android.

## What it demonstrates

- A `SpellCheckTextField` where misspelled words are underlined in real time.
- On desktop (Windows, Linux): right-click a misspelled word to see OS suggestions in the context menu.
- On Android: the OS spell checker handles everything natively.
- The platform backend label (WinRT / Hunspell / DefaultSpellCheckService).
- The native language tag resolved from the OS via `NativeSpellChecker.resolvedLanguageTag()`.

## Running

```bash
flutter pub get
flutter run -d windows   # or -d linux / -d <android-device-id>
```

## Tests

The example includes widget tests (`test/widget_test.dart`) that verify the platform backend label and the resolved native language display.

```bash
flutter test
```