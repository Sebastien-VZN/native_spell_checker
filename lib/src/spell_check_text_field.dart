import 'dart:io' show Platform;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter/services.dart';

import 'package:native_spell_checker/native_spell_checker.dart';

// ---------------------------------------------------------------------------
// Why this file exists — the right-click caret problem
// ---------------------------------------------------------------------------
//
// On desktop (Windows, Linux), Flutter's TextField does NOT reposition the
// caret when the user right-clicks inside the text. The internal
// TextSelectionGestureDetector only stores the tap position
// (lastSecondaryTapDownPosition) to anchor the context menu visually — it
// does not move the text selection to the clicked word.
//
// As a result, the context menu's suggestions are looked up at the *current*
// caret position (value.selection.baseOffset), not at the word the user
// actually right-clicked. If the caret is at the end of the text and the user
// right-clicks a misspelled word earlier in the sentence, no suggestions
// appear.
//
// SpellCheckTextField / SpellCheckTextFormField solve this by wrapping the
// native TextField / TextFormField in a Listener that intercepts the
// secondary button (right-click), repositions the caret to the clicked word
// via RenderEditable.getPositionForPoint, then lets Flutter open the
// context menu normally — so the suggestions are for the right-clicked word.
//
// See: flutter/packages/flutter/lib/src/widgets/text_selection.dart
//   → TextSelectionGestureDetector.onSecondaryTap (does not select the word
//     on Linux/Windows, only calls toggleToolbar).
//
// On Android, none of this is needed: the OS spell checker handles
// suggestions, context menu, and caret positioning natively.

/// Mixin providing shared spell-check and right-click cursor positioning
/// logic for [SpellCheckTextField] and [SpellCheckTextFormField].
mixin SpellCheckTextMixin<T extends StatefulWidget> on State<T> {
  /// Key attached to the inner [TextField] / [TextFormField] so the mixin
  /// can locate its [RenderEditable].
  GlobalKey get textFieldKey;

  /// The effective [TextEditingController] (owned or passed-in).
  TextEditingController get effectiveController;

  /// Walks the render subtree to find the first [RenderEditable].
  RenderEditable? _findRenderEditable(RenderObject root) {
    if (root is RenderEditable) return root;
    RenderEditable? result;
    root.visitChildren((child) {
      result ??= _findRenderEditable(child);
    });
    return result;
  }

  /// Moves the caret to the text position under [event] so the context menu
  /// shows suggestions for the right-clicked word.
  ///
  /// This runs synchronously in [Listener.onPointerDown], which fires before
  /// the TextField's gesture arena resolves — so by the time the
  /// [contextMenuBuilder] is called, the selection already points at the
  /// right-clicked word.
  void _handleSecondaryTap(PointerDownEvent event) {
    final box = textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final editable = _findRenderEditable(box);
    if (editable == null) return;

    final position = editable.getPositionForPoint(event.position);
    effectiveController.selection = TextSelection.fromPosition(position);
  }

  /// Builds the [SpellCheckConfiguration] for the current platform.
  ///
  /// On desktop, wires the native OS spell checker with optional custom
  /// styles. On Android, returns an empty configuration so Flutter uses
  /// [DefaultSpellCheckService] automatically.
  SpellCheckConfiguration _buildSpellCheckConfiguration({
    TextStyle? misspelledTextStyle,
    Color? misspelledSelectionColor,
  }) {
    final svc = NativeSpellChecker.service;
    if (svc != null) {
      return SpellCheckConfiguration(
        spellCheckService: svc,
        misspelledTextStyle: misspelledTextStyle ?? NativeSpellChecker.defaultMisspelledTextStyle,
        misspelledSelectionColor: misspelledSelectionColor,
      );
    }
    // Android: let Flutter use DefaultSpellCheckService.
    return const SpellCheckConfiguration();
  }

  /// Wraps [textField] with a [Listener] that intercepts right-clicks on
  /// desktop to reposition the caret before the context menu opens.
  ///
  /// On Android, returns [textField] unchanged (the OS handles everything).
  Widget _wrapWithRightClickListener(Widget textField) {
    if (!(Platform.isWindows || Platform.isLinux)) {
      return textField;
    }

    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kSecondaryButton) {
          _handleSecondaryTap(event);
        }
      },
      child: textField,
    );
  }
}

// ---------------------------------------------------------------------------
// SpellCheckTextField — drop-in replacement for TextField
// ---------------------------------------------------------------------------

/// A [TextField] with native OS spell checking and right-click suggestions
/// pre-wired.
///
/// On desktop (Windows, Linux), this widget:
/// - Enables native OS spell checking via [NativeSpellChecker].
/// - Wires a context menu that shows spelling suggestions above the standard
///   Cut/Copy/Paste/Select All buttons.
/// - Positions the caret at the right-click location before opening the
///   context menu, so suggestions appear for the word under the cursor
///   without requiring a prior left-click selection.
///
/// On Android, spell checking and suggestion menus are handled entirely by
/// the OS via [DefaultSpellCheckService] — this widget behaves like a plain
/// [TextField].
///
/// See the top of this file for why the right-click [Listener] is needed.
class SpellCheckTextField extends StatefulWidget {
  const SpellCheckTextField({
    this.controller,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.decoration,
    this.style,
    this.cursorColor,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.readOnly = false,
    this.autofocus = false,
    this.enabled = true,
    this.autofillHints,
    this.onChanged,
    this.onTap,
    this.onTapOutside,
    this.misspelledTextStyle,
    this.misspelledSelectionColor,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final InputDecoration? decoration;
  final TextStyle? style;
  final Color? cursorColor;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool readOnly;
  final bool autofocus;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final TapRegionCallback? onTapOutside;
  final TextStyle? misspelledTextStyle;
  final Color? misspelledSelectionColor;

  @override
  State<SpellCheckTextField> createState() => _SpellCheckTextFieldState();
}

class _SpellCheckTextFieldState extends State<SpellCheckTextField> with SpellCheckTextMixin<SpellCheckTextField> {
  final GlobalKey _textFieldKey = GlobalKey();
  TextEditingController? _internalController;

  @override
  GlobalKey get textFieldKey => _textFieldKey;

  @override
  TextEditingController get effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _wrapWithRightClickListener(
      TextField(
        key: _textFieldKey,
        controller: effectiveController,
        focusNode: widget.focusNode,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        decoration: widget.decoration,
        style: widget.style,
        cursorColor: widget.cursorColor,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        obscureText: widget.obscureText,
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        autofillHints: widget.autofillHints,
        onChanged: widget.onChanged,
        onTap: widget.onTap,
        onTapOutside: widget.onTapOutside,
        spellCheckConfiguration: _buildSpellCheckConfiguration(
          misspelledTextStyle: widget.misspelledTextStyle,
          misspelledSelectionColor: widget.misspelledSelectionColor,
        ),
        contextMenuBuilder: NativeSpellChecker.contextMenuBuilder,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SpellCheckTextFormField — drop-in replacement for TextFormField
// ---------------------------------------------------------------------------

/// A [TextFormField] with native OS spell checking and right-click
/// suggestions pre-wired.
///
/// Identical to [SpellCheckTextField] but based on [TextFormField] so it
/// supports [validator], [onFieldSubmitted], [onSaved], [initialValue], and
/// [autovalidateMode].
///
/// See the top of this file for why the right-click [Listener] is needed.
class SpellCheckTextFormField extends StatefulWidget {
  const SpellCheckTextFormField({
    this.controller,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.decoration,
    this.style,
    this.cursorColor,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.readOnly = false,
    this.autofocus = false,
    this.enabled = true,
    this.autofillHints,
    this.onChanged,
    this.onTap,
    this.onTapOutside,
    this.validator,
    this.onFieldSubmitted,
    this.onSaved,
    this.initialValue,
    this.autovalidateMode,
    this.misspelledTextStyle,
    this.misspelledSelectionColor,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final InputDecoration? decoration;
  final TextStyle? style;
  final Color? cursorColor;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool readOnly;
  final bool autofocus;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final TapRegionCallback? onTapOutside;

  // Form-specific
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldSetter<String>? onSaved;
  final String? initialValue;
  final AutovalidateMode? autovalidateMode;

  final TextStyle? misspelledTextStyle;
  final Color? misspelledSelectionColor;

  @override
  State<SpellCheckTextFormField> createState() => _SpellCheckTextFormFieldState();
}

class _SpellCheckTextFormFieldState extends State<SpellCheckTextFormField>
    with SpellCheckTextMixin<SpellCheckTextFormField> {
  final GlobalKey _textFieldKey = GlobalKey();
  TextEditingController? _internalController;

  @override
  GlobalKey get textFieldKey => _textFieldKey;

  @override
  TextEditingController get effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController(text: widget.initialValue));

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _wrapWithRightClickListener(
      TextFormField(
        key: _textFieldKey,
        controller: effectiveController,
        focusNode: widget.focusNode,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        decoration: widget.decoration,
        style: widget.style,
        cursorColor: widget.cursorColor,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        obscureText: widget.obscureText,
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        autofillHints: widget.autofillHints,
        onChanged: widget.onChanged,
        onTap: widget.onTap,
        onTapOutside: widget.onTapOutside,
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
        onSaved: widget.onSaved,
        initialValue: widget.initialValue,
        autovalidateMode: widget.autovalidateMode,
        spellCheckConfiguration: _buildSpellCheckConfiguration(
          misspelledTextStyle: widget.misspelledTextStyle,
          misspelledSelectionColor: widget.misspelledSelectionColor,
        ),
        contextMenuBuilder: NativeSpellChecker.contextMenuBuilder,
      ),
    );
  }
}
