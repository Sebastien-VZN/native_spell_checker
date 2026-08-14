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
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
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

  @override
  void initState() {
    super.initState();
    _updatePlatformInfo();
  }

  void _updatePlatformInfo() {
    final service = NativeSpellChecker.service;
    if (service == null) {
      _platformInfo = 'Android — using Flutter DefaultSpellCheckService';
    } else if (service.toString().contains('Windows')) {
      _platformInfo = 'Windows — using WinRT ISpellChecker2';
    } else if (service.toString().contains('Linux')) {
      _platformInfo = 'Linux — using libhunspell-1.7';
    } else {
      _platformInfo = 'Unknown platform';
    }
    setState(() {});
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
            Text('Platform backend', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(_platformInfo),
            const SizedBox(height: 24),
            Text('Try typing some misspelled words:', style: Theme.of(context).textTheme.titleMedium),
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
