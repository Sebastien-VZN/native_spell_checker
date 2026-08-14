import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'package:native_spell_checker/native_spell_checker.dart';

void main() {
  runApp(const NativeSpellCheckerExampleApp());
}

class NativeSpellCheckerExampleApp extends StatelessWidget {
  const NativeSpellCheckerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'native_spell_checker Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SpellCheckDemoPage(),
    );
  }
}

class SpellCheckDemoPage extends StatefulWidget {
  const SpellCheckDemoPage({super.key});

  @override
  State<SpellCheckDemoPage> createState() => _SpellCheckDemoPageState();
}

class _SpellCheckDemoPageState extends State<SpellCheckDemoPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _platformInfo = '';
  String _nativeLanguage = '';

  @override
  void initState() {
    super.initState();
    _updatePlatformInfo();
  }

  Future<void> _updatePlatformInfo() async {
    // Platform detection — `dart:io` Platform.isX is the only reliable source
    // of truth. The previous code relied on `service.toString().contains(...)`
    // which never matched (default `toString()` => `Instance of '...'`).
    if (Platform.isWindows) {
      _platformInfo = 'Windows — using WinRT ISpellChecker2';
    } else if (Platform.isLinux) {
      _platformInfo = 'Linux — using libhunspell-1.7';
    } else if (Platform.isAndroid) {
      _platformInfo = 'Android — using Flutter DefaultSpellCheckService';
    } else {
      _platformInfo = 'Unknown platform';
    }

    // Native language detection — on desktop, ask the OS spell checker
    // which dictionary it will actually use (after fallback). On Android,
    // the plugin defers to Flutter, so fall back to the system locale.
    if (Platform.isWindows || Platform.isLinux) {
      final tag = await NativeSpellChecker.resolvedLanguageTag();
      _nativeLanguage = tag ?? '(no dictionary available)';
    } else if (Platform.isAndroid) {
      _nativeLanguage = Platform.localeName;
    } else {
      _nativeLanguage = '(unsupported)';
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('native_spell_checker')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform backend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(_platformInfo),
            const SizedBox(height: 8),
            Text(
              'Native language',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _nativeLanguage.isEmpty ? '(loading...)' : _nativeLanguage,
              key: const ValueKey('nativeLanguageValue'),
            ),
            const SizedBox(height: 24),
            Text(
              'Try typing some misspelled words:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Type here to see spell check in action...',
              ),
              spellCheckConfiguration: NativeSpellChecker.configuration(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Misspelled words are underlined in red.\n'
              'On desktop, right-click for suggestions.\n'
              'On Android, the OS spell checker handles everything.',
            ),
          ],
        ),
      ),
    );
  }
}
