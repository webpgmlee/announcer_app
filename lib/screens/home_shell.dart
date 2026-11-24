// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';
import 'history_screen.dart';
import 'record_screen.dart';
import 'script_list_screen.dart';

/// 아래 탭 세 개: 대본 / 녹음 / 기록.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeTabProvider);
    final script = ref.watch(currentScriptProvider);

    final body = switch (tab) {
      0 => ScriptListScreen(onOpen: (context, s) {
          ref.read(currentScriptProvider.notifier).select(s);
          ref.read(homeTabProvider.notifier).go(1);
        }),
      1 when script != null => RecordScreen(key: ValueKey('record-${script.id}'), script: script),
      2 when script != null => HistoryScreen(key: ValueKey('history-${script.id}'), script: script),
      _ => _PickScript(onPick: () => ref.read(homeTabProvider.notifier).go(0)),
    };

    return Scaffold(
      body: body,
      bottomNavigationBar: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (final (i, label) in const [(0, '대본'), (1, '녹음'), (2, '기록')])
                Expanded(
                  child: InkWell(
                    onTap: () => ref.read(homeTabProvider.notifier).go(i),
                    child: Center(
                      child: Text(label,
                          style: TextStyle(
                            fontSize: 16,
                            color: tab == i ? Palette.ink : Palette.faint,
                            fontWeight: tab == i ? FontWeight.w600 : FontWeight.w400,
                          )),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickScript extends StatelessWidget {
  const _PickScript({required this.onPick});
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('대본 탭에서 원고를 골라 주세요',
                  style: TextStyle(fontSize: 18, color: Palette.muted)),
              const SizedBox(height: 16),
              FilledButton(onPressed: onPick, child: const Text('원고 고르기')),
            ],
          ),
        ),
      );
}
