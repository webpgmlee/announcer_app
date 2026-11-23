// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../providers.dart';
import 'result_screen.dart';

final sessionsForScriptProvider = FutureProvider.family<List<PracticeSession>, int>(
    (ref, scriptId) => ref.watch(sessionRepositoryProvider).forScript(scriptId));

String formatDateTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}.${two(t.month)}.${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// 원고 하나의 연습 기록 (최신순).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, required this.script});
  final Script script;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  /// 밀어서 지운 기록. 다시 불러오기 전에 바로 화면에서 뺀다.
  final _removed = <int>{};

  Script get script => widget.script;

  Future<bool> _confirm(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('이 기록을 지울까요?'),
          content: const Text('녹음 파일도 함께 지워지고 되돌릴 수 없어요.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('지우기')),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsForScriptProvider(script.id!));
    final visible =
        sessions.value?.where((s) => !_removed.contains(s.id)).toList();
    return Scaffold(
      appBar: AppBar(title: Text('${script.title} 기록')),
      body: switch (sessions) {
        AsyncData() when visible!.isEmpty =>
          const Center(child: Text('아직 연습 기록이 없어요')),
        AsyncData() => ListView.separated(
            itemCount: visible!.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = visible[i];
              return Dismissible(
                key: ValueKey(s.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete_outline),
                ),
                confirmDismiss: (_) => _confirm(context),
                onDismissed: (_) async {
                  setState(() => _removed.add(s.id!));
                  await ref.read(sessionRepositoryProvider).delete(s.id!);
                  ref.invalidate(sessionsForScriptProvider(script.id!));
                },
                child: ListTile(
                  title: Text(formatDateTime(s.createdAt)),
                  subtitle: Text(
                      '${formatDuration(s.elapsed)} · 1분당 ${s.syllablesPerMinute.round()}음절'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ResultScreen(script: script, session: s))),
                ),
              );
            },
          ),
        AsyncError() => const Center(child: Text('기록을 불러오지 못했어요')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
