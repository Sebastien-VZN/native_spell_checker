# native_spell_checker

[![pub package](https://img.shields.io/pub/v/native_spell_checker.svg)](https://pub.dev/packages/native_spell_checker)
[![likes](https://img.shields.io/pub/likes/native_spell_checker?logo=dart)](https://pub.dev/packages/native_spell_checker/score)
[![pub points](https://img.shields.io/pub/points/native_spell_checker?logo=dart)](https://pub.dev/packages/native_spell_checker/score)

A Flutter plugin for native OS spell checking on desktop (Windows, Linux) — zero bundled dictionaries, uses the operating system's built-in spell checker. On Android, it defers to Flutter's built-in `DefaultSpellCheckService`.

- **pub.dev:** https://pub.dev/packages/native_spell_checker
- **Repository:** https://github.com/Sebastien-VZN/native_spell_checker

> For the full technical reference (architecture, design decisions, testing protocol), see [README_GH.md](https://github.com/Sebastien-VZN/native_spell_checker/blob/main/README_GH.md).
>
> Version française : [README_FR.md](https://github.com/Sebastien-VZN/native_spell_checker/blob/main/README_FR.md).

## Screenshots

| Windows | Linux | Android |
|---|---|---|
| ![Windows demo](https://raw.githubusercontent.com/Sebastien-VZN/native_spell_checker/main/doc/screen_windows.jpg) | ![Linux demo](https://raw.githubusercontent.com/Sebastien-VZN/native_spell_checker/main/doc/screen_linux.jpg) | ![Android demo](https://raw.githubusercontent.com/Sebastien-VZN/native_spell_checker/main/doc/screen_android.jpg) |

## Features

- **Windows**: Uses WinRT `ISpellChecker2` (COM API) via the [`win32`](https://pub.dev/packages/win32) package.
- **Linux**: Uses `libhunspell-1.7` system library via `dart:ffi`. Dictionaries are read from `/usr/share/hunspell/`.
- **Android**: Defers to Flutter's built-in `DefaultSpellCheckService` (no code needed).
- **Zero bundled dictionaries** — the OS provides everything.
- **Multi-language** — automatically uses the OS-installed dictionaries for the current locale.
- **100% offline** — no cloud APIs, no network calls.
- **Context menu suggestions** — right-click a misspelled word on desktop to see OS suggestions.
- **Drop-in widgets** — `SpellCheckTextField` / `SpellCheckTextFormField` as direct replacements for `TextField` / `TextFormField`.

## Getting started

Add the dependency:

```yaml
dependencies:
  native_spell_checker: ^0.4.0
```

### Linux prerequisite

The `libhunspell-1.7-0` package must be installed on the target system. On Debian/Ubuntu:

```bash
sudo apt-get install libhunspell-1.7-0 hunspell-fr hunspell-en-us
```

Dictionaries are provided by `hunspell-*` packages and stored in `/usr/share/hunspell/`.

## Usage

### Option A — drop-in widget (recommended)

Use `SpellCheckTextField` or `SpellCheckTextFormField` as a drop-in replacement for `TextField` / `TextFormField`. Spell checking, context menu suggestions, and right-click caret positioning are all pre-wired:

```dart
import 'package:native_spell_checker/native_spell_checker.dart';

SpellCheckTextField(
  controller: myController,
  maxLines: 5,
  decoration: const InputDecoration(hintText: 'Type here...'),
)
```

For forms with validation:

```dart
SpellCheckTextFormField(
  controller: myController,
  validator: (value) => value!.isEmpty ? 'Required' : null,
  maxLines: 5,
  decoration: const InputDecoration(hintText: 'Type here...'),
  misspelledTextStyle: myCustomStyle,
  misspelledSelectionColor: Colors.red,
)
```

#### Why the wrapper widget?

On desktop (Windows, Linux), Flutter's `TextField` does **not** reposition the caret when the user right-clicks. The internal `TextSelectionGestureDetector` only stores the tap position to anchor the context menu visually — it does not move the text selection to the clicked word. So the context menu's suggestions are looked up at the *current* caret position, not at the word the user actually right-clicked.

`SpellCheckTextField` / `SpellCheckTextFormField` wrap the native `TextField` / `TextFormField` in a `Listener` that intercepts the secondary button (right-click), repositions the caret to the clicked word via `RenderEditable.getPositionForPoint`, then lets Flutter open the context menu normally. The suggestions shown are for the right-clicked word, without requiring a prior left-click selection.

On Android, the wrapper is a no-op — the OS handles everything natively.

### Option B — manual wiring

If you need full control, wire the three building blocks yourself:

```dart
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:native_spell_checker/native_spell_checker.dart';

final GlobalKey _key = GlobalKey();

Listener(
  onPointerDown: (event) {
    if (event.buttons == kSecondaryButton) {
      NativeSpellChecker.onSecondaryTapDown(_key, controller, event);
    }
  },
  child: TextField(
    key: _key,
    controller: controller,
    spellCheckConfiguration: NativeSpellChecker.configuration(),
    contextMenuBuilder: NativeSpellChecker.contextMenuBuilder,
  ),
)
```

Available building blocks:

- `NativeSpellChecker.configuration(misspelledTextStyle)` — returns a `SpellCheckConfiguration` wired to the OS spell checker.
- `NativeSpellChecker.contextMenuBuilder` — builds a context menu with spelling suggestions above the standard Cut/Copy/Paste/Select All buttons.
- `NativeSpellChecker.onSecondaryTapDown(key, controller, event)` — repositions the caret to the right-click location.

### Discover the language the spell checker will use

```dart
// null locale → resolve from the OS default locale.
final tag = await NativeSpellChecker.resolvedLanguageTag();
// e.g. "fr-FR" (Windows BCP-47) / "fr_FR" (Linux Hunspell) / null (Android)

// explicit locale → same fallback chain used during spell checking.
final enTag = await NativeSpellChecker.resolvedLanguageTag(locale: const Locale('en', 'US'));
```

Returns `null` on Android (where the plugin defers to Flutter). Use `Platform.localeName` to read the system locale on Android.

## How it works

| Platform | Backend | Dictionary source | Language tag format |
|---|---|---|---|
| Android | Flutter `DefaultSpellCheckService` | OS (TextServicesManager) | `null` (use `Platform.localeName`) |
| Windows | WinRT `ISpellChecker2` (COM FFI) | OS (Windows SpellChecker) | BCP-47 (`fr-FR`, `en-US`) |
| Linux | `libhunspell-1.7` (dart:ffi) | `/usr/share/hunspell/` | Hunspell (`fr_FR`, `en_US`) |

## Platforms

| Platform | Status |
|---|---|
| Android | Manually validated |
| Linux | Manually validated |
| Windows | Manually validated |
| iOS | Not supported |
| macOS | Not supported |

## License

MIT — see [LICENSE](https://github.com/Sebastien-VZN/native_spell_checker/blob/main/LICENSE).