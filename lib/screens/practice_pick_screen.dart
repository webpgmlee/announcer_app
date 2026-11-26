// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/script_browser.dart';
import 'record_screen.dart';
import 'script_manage_screen.dart';

/// 녹음 화면을 독립 화면으로 연다 (뒤로 가기로 돌아옴).
Future<void> openRecordPage(BuildContext context, WidgetRef ref, Script script) async {
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => Scaffold(
      appBar: AppBar(toolbarHeight: 44),
      body: RecordScreen(script: script),
    ),
  ));
  refreshLists(ref);
}

/// 발음연습: 원고를 고르면 녹음 화면으로 간다.
class PracticePickScreen extends ConsumerStatefulWidget {
  const PracticePickScreen({super.key});

  @override
  ConsumerState<PracticePickScreen> createState() => _PracticePickScreenState();
}

class _PracticePickScreenState extends ConsumerState<PracticePickScreen> {
  @override
  Widget build(BuildContext context) {
    final scripts = ref.watch(scriptsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('발음연습')),
      body: switch (scripts) {
        AsyncData(:final value) when value.isEmpty => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('연습할 원고가 없어요',
                    style: TextStyle(fontSize: 18, color: Palette.muted)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const ScriptManageScreen())),
                  child: const Text('원고관리로 가기'),
                ),
              ],
            ),
          ),
        AsyncData() => ScriptBrowser(
            onOpen: (s) => openRecordPage(context, ref, s),
            trailing: (_, _) => const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.mic_none, color: Palette.muted),
            ),
          ),
        AsyncError() => const Center(child: Text('원고를 불러오지 못했어요')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
