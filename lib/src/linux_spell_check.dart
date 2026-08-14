import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- FFI bindings for libhunspell-1.7 ---

/// Opaque handle to a Hunspell instance.
final class Hunhandle extends Opaque {}

/// FFI bindings to `libhunspell-1.7.so.0`.
final class _HunspellBindings {
  _HunspellBindings._(this._lib);

  final DynamicLibrary _lib;

  late final Pointer<Hunhandle> Function(Pointer<Utf8> affpath, Pointer<Utf8> dpath) create = _lib
      .lookupFunction<
        Pointer<Hunhandle> Function(Pointer<Utf8>, Pointer<Utf8>),
        Pointer<Hunhandle> Function(Pointer<Utf8>, Pointer<Utf8>)
      >("Hunspell_create");

  late final void Function(Pointer<Hunhandle>) destroy = _lib
      .lookupFunction<Void Function(Pointer<Hunhandle>), void Function(Pointer<Hunhandle>)>("Hunspell_destroy");

  late final int Function(Pointer<Hunhandle>, Pointer<Utf8>) spell = _lib
      .lookupFunction<
        Int32 Function(Pointer<Hunhandle>, Pointer<Utf8>),
        int Function(Pointer<Hunhandle>, Pointer<Utf8>)
      >("Hunspell_spell");

  late final int Function(Pointer<Hunhandle>, Pointer<Pointer<Pointer<Utf8>>>, Pointer<Utf8>) suggest = _lib
      .lookupFunction<
        Int32 Function(Pointer<Hunhandle>, Pointer<Pointer<Pointer<Utf8>>>, Pointer<Utf8>),
        int Function(Pointer<Hunhandle>, Pointer<Pointer<Pointer<Utf8>>>, Pointer<Utf8>)
      >("Hunspell_suggest");

  late final void Function(Pointer<Hunhandle>, Pointer<Pointer<Pointer<Utf8>>>, int) freeList = _lib
      .lookupFunction<
        Void Function(Pointer<Hunhandle>, Pointer<Pointer<Pointer<Utf8>>>, Int32),
        void Function(Pointer<Hunhandle>, Pointer<Pointer<Pointer<Utf8>>>, int)
      >("Hunspell_free_list");
}

/// Linux spell check service backed by `libhunspell-1.7` via `dart:ffi`.
///
/// Dictionaries are read from `/usr/share/hunspell/` — no bundled assets.
/// The `libhunspell-1.7-0` system package must be installed.
class LinuxSpellCheckService extends SpellCheckService {
  /// Creates a [LinuxSpellCheckService].
  LinuxSpellCheckService();

  _HunspellBindings? _bindings;
  Pointer<Hunhandle>? _handle;
  String? _currentLocale;

  /// Regex to split text into words (letters including accented chars and apostrophes).
  static final RegExp _wordRegExp = RegExp(r"[a-zA-ZàâæçéèêëîïôœùûüÿÀÂÆÇÉÈÊËÎÏÔŒÙÛÜŸ''-]+");

  void _ensureBindings() {
    if (_bindings != null) return;
    final lib = DynamicLibrary.open("libhunspell-1.7.so.0");
    _bindings = _HunspellBindings._(lib);
  }

  /// Loads the Hunspell dictionary for the given [locale].
  ///
  /// Dictionary files are expected at:
  ///   `/usr/share/hunspell/{locale}.aff` and `/usr/share/hunspell/{locale}.dic`
  void _ensureDictionary(Locale locale) {
    final tag = _localeToHunspellName(locale);
    if (tag == _currentLocale && _handle != null) return;

    // Destroy previous handle if any.
    if (_handle != null && _bindings != null) {
      _bindings!.destroy(_handle!);
      _handle = null;
    }

    final dictDir = "/usr/share/hunspell";
    final candidates = <String>[
      "$dictDir/$tag.aff",
      "$dictDir/${locale.languageCode}_${locale.countryCode ?? ""}.aff",
      "$dictDir/${locale.languageCode}.aff",
    ];

    String? affPath;
    String? dicPath;
    for (final aff in candidates) {
      final dic = aff.replaceAll(".aff", ".dic");
      if (File(aff).existsSync() && File(dic).existsSync()) {
        affPath = aff;
        dicPath = dic;
        break;
      }
    }

    if (affPath == null || dicPath == null) return;

    _ensureBindings();

    using((arena) {
      final affPtr = affPath!.toNativeUtf8(allocator: arena);
      final dicPtr = dicPath!.toNativeUtf8(allocator: arena);
      _handle = _bindings!.create(affPtr, dicPtr);
    });

    _currentLocale = tag;
  }

  /// Converts a [Locale] to a Hunspell dictionary name (e.g. "fr_FR", "en_US").
  String _localeToHunspellName(Locale locale) {
    final language = locale.languageCode.toLowerCase();
    final country = locale.countryCode?.toUpperCase();
    if (country != null && country.isNotEmpty) {
      return "${language}_$country";
    }
    return language;
  }

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) async {
    if (text.isEmpty) return <SuggestionSpan>[];

    _ensureBindings();
    _ensureDictionary(locale);

    if (_handle == null || _bindings == null) return null;

    final spans = <SuggestionSpan>[];
    final matches = _wordRegExp.allMatches(text);

    for (final match in matches) {
      final word = text.substring(match.start, match.end);

      // Check if the word is spelled correctly.
      final isCorrect = using((arena) {
        final wordPtr = word.toNativeUtf8(allocator: arena);
        return _bindings!.spell(_handle!, wordPtr) != 0;
      });

      if (isCorrect) continue;

      // Collect suggestions for the misspelled word.
      final suggestions = _collectSuggestions(word);
      spans.add(SuggestionSpan(TextRange(start: match.start, end: match.end), suggestions));
    }

    return spans;
  }

  /// Collects spelling suggestions for a misspelled word.
  List<String> _collectSuggestions(String word) {
    return using((arena) {
      final slst = arena<Pointer<Pointer<Utf8>>>();
      final wordPtr = word.toNativeUtf8(allocator: arena);
      final count = _bindings!.suggest(_handle!, slst, wordPtr);

      final suggestions = <String>[];
      for (var i = 0; i < count; i++) {
        final strPtr = slst.value[i];
        if (strPtr != nullptr) {
          suggestions.add(strPtr.toDartString());
        }
      }

      if (count > 0) {
        _bindings!.freeList(_handle!, slst, count);
      }

      return suggestions;
    });
  }

  /// Releases the Hunspell handle. Call when the service is no longer needed.
  void dispose() {
    if (_handle != null && _bindings != null) {
      _bindings!.destroy(_handle!);
      _handle = null;
    }
  }
}
