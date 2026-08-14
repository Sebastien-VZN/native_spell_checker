import 'dart:io' show Platform;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter/services.dart';

import 'package:native_spell_checker/native_spell_checker.dart';

/// A [TextField] with native spell checking and right-click suggestions
/// pre-wired.
///
/// On desktop (Windows, Linux), this widget:
/// - Enables native OS spell checking via [NativeSpellChecker.configuration].
/// - Wires a context menu that shows spelling suggestions above the standard
///   Cut/Copy/Paste/Select All buttons.
/// - Positions the caret at the right-click location before opening the
///   context menu, so suggestions appear for the word under the cursor
///   without requiring a prior left-click selection.
///
/// On Android, spell checking and suggestion menus are handled entirely by
/// the OS via [DefaultSpellCheckService] — this widget behaves like a plain
/// [TextField] with [SpellCheckConfiguration()].
///
/// Example:
///
/// ```dart
/// SpellCheckTextField(
///   controller: myController,
///   maxLines: 5,
///   decoration: const InputDecoration(hintText: 'Type here...'),
/// )
/// ```
class SpellCheckTextField extends StatefulWidget {
  const SpellCheckTextField({
    this.controller,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
    this.decoration,
    this.style,
    this.autofocus = false,
    this.onChanged,
    super.key,
  });

  /// Controls the text being edited. If null, an internal controller is
  /// created and disposed automatically.
  final TextEditingController? controller;

  final FocusNode? focusNode;
  final int? maxLines;
  final int? minLines;
  final InputDecoration? decoration;
  final TextStyle? style;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  State<SpellCheckTextField> createState() => _SpellCheckTextFieldState();
}

class _SpellCheckTextFieldState extends State<SpellCheckTextField> {
  final GlobalKey _textFieldKey = GlobalKey();
  TextEditingController? _internalController;

  TextEditingController get _effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  /// Walks the render subtree starting from [root] to find the first
  /// [RenderEditable], which is the leaf render object that lays out the
  /// text inside a [TextField].
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
  /// the [TextField]'s gesture arena resolves — so by the time the
  /// [contextMenuBuilder] is called, the selection already points at the
  /// right-clicked word.
  void _handleSecondaryTap(PointerDownEvent event) {
    final textFieldBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (textFieldBox == null) return;

    final renderEditable = _findRenderEditable(textFieldBox);
    if (renderEditable == null) return;

    final textPosition = renderEditable.getPositionForPoint(event.position);

    _effectiveController.selection = TextSelection.fromPosition(textPosition);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isLinux;

    if (!isDesktop) {
      // Android: plain TextField with native spell check.
      return TextField(
        controller: _effectiveController,
        focusNode: widget.focusNode,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        decoration: widget.decoration,
        style: widget.style,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        spellCheckConfiguration: const SpellCheckConfiguration(),
      );
    }

    // Desktop: wrap with Listener for right-click cursor positioning.
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kSecondaryButton) {
          _handleSecondaryTap(event);
        }
      },
      child: TextField(
        key: _textFieldKey,
        controller: _effectiveController,
        focusNode: widget.focusNode,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        decoration: widget.decoration,
        style: widget.style,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        spellCheckConfiguration: NativeSpellChecker.configuration(),
        contextMenuBuilder: NativeSpellChecker.contextMenuBuilder,
      ),
    );
  }
}
