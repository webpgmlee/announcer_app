// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/syllables.dart';
import '../data/models.dart';
import '../data/practice_state.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/script_browser.dart';
import 'practice_pick_screen.dart';

/// 원고 조회: 난이도·폴더·연습 상태, 음절 수·예상 시간·녹음 횟수, 본문 전체.
class ScriptDetailScreen extends ConsumerWidget {
  const ScriptDetailScreen({super.key, required this.script});
  final Script script;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 연습 완료 등으로 바뀐 최신 상태를 쓴다.
    final s = (ref.watch(scriptsProvider).value ?? const <Script>[])
            .where((x) => x.id == script.id)
            .firstOrNull ??
        script;
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final folder = folders.where((f) => f.id == s.folderId).firstOrNull;
    final stat = (ref.watch(practiceStatsProvider).value ?? const {})[s.id];
    final practicing = isPracticing(s, stat);
    final syllables = countSyllables(s.body);

    Widget info(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Palette.muted),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Palette.muted)),
        ]);

    return Scaffold(
      appBar: AppBar(title: Text(displayTitle(s.title))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (s.difficulty != null && s.difficulty! >= 1 && s.difficulty! <= 3)
                LevelBadge(level: s.difficulty!),
              Chip(
                avatar: const Icon(Icons.folder_outlined, size: 16),
                label: Text(folder?.name ?? '폴더 없음'),
                visualDensity: VisualDensity.compact,
              ),
              if (practicing)
                const Chip(
                  avatar: Icon(Icons.mic_none, size: 16, color: Palette.red),
                  label: Text('연습 중'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 4, children: [
            info(Icons.text_fields, '$syllables음절'),
            info(Icons.timer_outlined, readingTime(syllables)),
            info(Icons.graphic_eq, stat == null ? '녹음 없음' : '녹음 ${stat.count}번'),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.line),
            ),
            child: Text(keepWords(s.body),
                style: const TextStyle(fontSize: 19, height: 1.75, fontWeight: FontWeight.w300)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => openRecordPage(context, ref, s),
            icon: const Icon(Icons.mic_none),
            label: const Text('이 원고로 연습'),
          ),
          if (practicing) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () async {
                await ref.read(scriptRepositoryProvider).markCompleted(s.id!);
                refreshLists(ref);
              },
              icon: const Icon(Icons.check),
              label: const Text('연습 완료'),
            ),
          ],
        ],
      ),
    );
  }
}
