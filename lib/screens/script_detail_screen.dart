// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/syllables.dart';
import '../data/models.dart';
import '../providers.dart';
import '../theme.dart';
import 'practice_pick_screen.dart';

/// 원고 조회: 폴더, 음절 수, 녹음 횟수, 본문 전체.
class ScriptDetailScreen extends ConsumerWidget {
  const ScriptDetailScreen({super.key, required this.script});
  final Script script;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final folder = folders.where((f) => f.id == script.folderId).firstOrNull;
    final count = ref.watch(sessionsForScriptProvider(script.id!)).value?.length;
    const meta = TextStyle(color: Palette.muted);

    return Scaffold(
      appBar: AppBar(title: Text(script.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Wrap(spacing: 16, children: [
            Text(folder?.name ?? '폴더 없음', style: meta),
            Text('${countSyllables(script.body)}음절', style: meta),
            if (count != null) Text('녹음 $count번', style: meta),
          ]),
          const SizedBox(height: 20),
          Text(script.body,
              style: const TextStyle(fontSize: 20, height: 1.7, fontWeight: FontWeight.w300)),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => openRecordPage(context, ref, script),
            icon: const Icon(Icons.mic_none),
            label: const Text('이 원고로 연습'),
          ),
        ],
      ),
    );
  }
}
