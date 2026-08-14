# native_spell_checker

Un plugin Flutter pour la correction orthographique native de l'OS sur desktop (Windows, Linux) — zéro dictionnaire bundlé, utilise le correcteur orthographique intégré du système d'exploitation. Sur Android, il délègue au `DefaultSpellCheckService` intégré de Flutter.

- **pub.dev :** https://pub.dev/packages/native_spell_checker
- **Dépôt :** https://github.com/Sebastien-VZN/native_spell_checker

> Pour la référence technique complète (architecture, décisions de design, protocole de test), voir [README_GH_FR.md](https://github.com/Sebastien-VZN/native_spell_checker/blob/main/README_GH_FR.md).
>
> English version: [README.md](https://github.com/Sebastien-VZN/native_spell_checker/blob/main/README.md).

## Captures d'écran

| Windows | Linux | Android |
|---|---|---|
| ![Démo Windows](https://raw.githubusercontent.com/Sebastien-VZN/native_spell_checker/main/doc/screen_windows.jpg) | ![Démo Linux](https://raw.githubusercontent.com/Sebastien-VZN/native_spell_checker/main/doc/screen_linux.jpg) | ![Démo Android](https://raw.githubusercontent.com/Sebastien-VZN/native_spell_checker/main/doc/screen_android.jpg) |

## Fonctionnalités

- **Windows** : Utilise WinRT `ISpellChecker2` (API COM) via le package [`win32`](https://pub.dev/packages/win32).
- **Linux** : Utilise la bibliothèque système `libhunspell-1.7` via `dart:ffi`. Les dictionnaires sont lus depuis `/usr/share/hunspell/`.
- **Android** : Délègue au `DefaultSpellCheckService` intégré de Flutter (aucun code nécessaire).
- **Zéro dictionnaire bundlé** — l'OS fournit tout.
- **Multilingue** — utilise automatiquement les dictionnaires installés sur l'OS pour la locale courante.
- **100% hors ligne** — aucune API cloud, aucun appel réseau.
- **Suggestions en menu contextuel** — clic droit sur un mot mal orthographié sur desktop pour voir les suggestions de l'OS.
- **Widgets drop-in** — `SpellCheckTextField` / `SpellCheckTextFormField` comme remplaçants directs de `TextField` / `TextFormField`.

## Démarrage

Ajoutez la dépendance :

```yaml
dependencies:
  native_spell_checker: ^0.4.0
```

### Prérequis Linux

Le paquet `libhunspell-1.7-0` doit être installé sur le système cible. Sur Debian/Ubuntu :

```bash
sudo apt-get install libhunspell-1.7-0 hunspell-fr hunspell-en-us
```

Les dictionnaires sont fournis par les paquets `hunspell-*` et stockés dans `/usr/share/hunspell/`.

## Utilisation

### Option A — widget drop-in (recommandé)

Utilisez `SpellCheckTextField` ou `SpellCheckTextFormField` comme remplaçant direct de `TextField` / `TextFormField`. La correction orthographique, les suggestions du menu contextuel et le repositionnement du curseur au clic droit sont pré-câblés :

```dart
import 'package:native_spell_checker/native_spell_checker.dart';

SpellCheckTextField(
  controller: myController,
  maxLines: 5,
  decoration: const InputDecoration(hintText: 'Type here...'),
)
```

Pour les formulaires avec validation :

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

#### Pourquoi le widget wrapper ?

Sur desktop (Windows, Linux), le `TextField` de Flutter ne repositionne **pas** le curseur quand l'utilisateur fait un clic droit. Le `TextSelectionGestureDetector` interne stocke seulement la position du tap pour ancrer visuellement le menu contextuel — il ne déplace pas la sélection de texte vers le mot cliqué. Donc les suggestions du menu contextuel sont recherchées à la position *actuelle* du curseur, pas sur le mot que l'utilisateur a réellement cliqué.

`SpellCheckTextField` / `SpellCheckTextFormField` encapsulent le `TextField` / `TextFormField` natif dans un `Listener` qui intercepte le bouton secondaire (clic droit), repositionne le curseur sur le mot cliqué via `RenderEditable.getPositionForPoint`, puis laisse Flutter ouvrir le menu contextuel normalement. Les suggestions affichées correspondent au mot cliqué, sans nécessiter de sélection préalable au clic gauche.

Sur Android, le wrapper est un no-op — l'OS gère tout nativement.

### Option B — câblage manuel

Si vous avez besoin d'un contrôle total, raccordez les trois briques vous-même :

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

Briques disponibles :

- `NativeSpellChecker.configuration(misspelledTextStyle)` — retourne une `SpellCheckConfiguration` branchée sur le correcteur de l'OS.
- `NativeSpellChecker.contextMenuBuilder` — construit un menu contextuel avec les suggestions orthographiques au-dessus des boutons standard Cut/Copy/Paste/Select All.
- `NativeSpellChecker.onSecondaryTapDown(key, controller, event)` — repositionne le curseur à l'emplacement du clic droit.

### Découvrir la langue que le correcteur utilisera

```dart
// locale null → résoudre depuis la locale par défaut de l'OS.
final tag = await NativeSpellChecker.resolvedLanguageTag();
// ex. "fr-FR" (Windows BCP-47) / "fr_FR" (Linux Hunspell) / null (Android)

// locale explicite → même chaîne de fallback que pendant la correction.
final enTag = await NativeSpellChecker.resolvedLanguageTag(locale: const Locale('en', 'US'));
```

Retourne `null` sur Android (où le plugin délègue à Flutter). Utilisez `Platform.localeName` pour lire la locale système sur Android.

## Fonctionnement

| Plateforme | Backend | Source des dictionnaires | Format du tag de langue |
|---|---|---|---|
| Android | Flutter `DefaultSpellCheckService` | OS (TextServicesManager) | `null` (utiliser `Platform.localeName`) |
| Windows | WinRT `ISpellChecker2` (COM FFI) | OS (Windows SpellChecker) | BCP-47 (`fr-FR`, `en-US`) |
| Linux | `libhunspell-1.7` (dart:ffi) | `/usr/share/hunspell/` | Hunspell (`fr_FR`, `en_US`) |

## Plateformes

| Plateforme | Statut |
|---|---|
| Android | Validé manuellement |
| Linux | Validé manuellement |
| Windows | Validé manuellement |
| iOS | Non supporté |
| macOS | Non supporté |

## Licence

MIT — voir [LICENSE](https://github.com/Sebastien-VZN/native_spell_checker/blob/main/LICENSE).