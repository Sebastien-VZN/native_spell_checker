# native_spell_checker

A Flutter plugin for native OS spell checking on desktop (Windows, Linux) — zero
bundled dictionaries, uses the operating system's built-in spell checker. On
Android, it defers to Flutter's built-in `DefaultSpellCheckService`.

This repository is a **pub workspace** (monorepo). The publishable plugin lives
under [`packages/native_spell_checker/`](packages/native_spell_checker), and the
runnable example app lives under
[`packages/native_spell_checker/example/`](packages/native_spell_checker/example).

## Repository layout

```
.
+- pubspec.yaml                          # workspace anchor (not published)
+- packages/
    +- native_spell_checker/             # the published Flutter plugin
        +- lib/                         # plugin Dart API + FFI backends
        +- test/                        # unit & contract tests
        +- example/                     # runnable example app (Windows/Linux/Android)
        +- pubspec.yaml                 # resolution: workspace
        +- README.md, CHANGELOG.md, LICENSE
```

See [`packages/native_spell_checker/README.md`](packages/native_spell_checker/README.md)
for usage, platform backends, and getting started.

## Development

Run once at the repository root (resolves the whole workspace):

```bash
flutter pub get
```

Then run/debug the example app from
`packages/native_spell_checker/example/`.

## License

MIT — see [LICENSE](LICENSE) and
[packages/native_spell_checker/LICENSE](packages/native_spell_checker/LICENSE).