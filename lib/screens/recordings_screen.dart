// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../providers.dart';
import '../theme.dart';
import 'result_screen.dart';

String formatDateTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}.${two(t.month)}.${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// 녹음관리: 모든 원고의 연습 녹음 (최신순). 누르면 결과, 밀어서 삭제.
class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  /// 밀어서 지운 기록. 다시 불러오기 전에 바로 화면에서 뺀다.
  final _removed = <int>{};

  Future<bool> _confirm() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('이 기록을 지울까요?'),
          content: const Text('녹음 파일도 함께 지워지고 되돌릴 수 없어요.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('지우기')),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(allSessionsProvider);
    final scripts = {
      for (final s in ref.watch(scriptsProvider).value ?? const <Script>[]) s.id: s,
    };
    final visible = sessions.value
        ?.where((s) => !_removed.contains(s.id) && scripts.containsKey(s.scriptId))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('녹음관리')),
      body: switch (sessions) {
        AsyncData() when visible!.isEmpty => const Center(
            child: Text('아직 연습 기록이 없어요', style: TextStyle(fontSize: 16, color: Palette.muted))),
        AsyncData() => ListView.separated(
            itemCount: visible!.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = visible[i];
              final script = scripts[s.scriptId]!;
              return Dismissible(
                key: ValueKey(s.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete_outline),
                ),
                confirmDismiss: (_) => _confirm(),
                onDismissed: (_) async {
                  setState(() => _removed.add(s.id!));
                  await ref.read(sessionRepositoryProvider).delete(s.id!);
                  refreshLists(ref);
                },
                child: ListTile(
                  title: Text(script.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${formatDateTime(s.createdAt)} · '
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
