// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/syllables.dart';
import '../data/models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/folder_chips.dart';
import 'folder_manage_screen.dart';
import 'script_detail_screen.dart';
import 'script_edit_screen.dart';

/// 원고관리: 조회, 추가, 복제, 폴더 이동, 삭제, 폴더 관리.
class ScriptManageScreen extends ConsumerStatefulWidget {
  const ScriptManageScreen({super.key});

  @override
  ConsumerState<ScriptManageScreen> createState() => _ScriptManageScreenState();
}

class _ScriptManageScreenState extends ConsumerState<ScriptManageScreen> {
  int _folder = allFolders;

  int? get _folderForNew => _folder > noFolder ? _folder : null;

  Future<void> _add() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ScriptEditScreen(initialFolderId: _folderForNew)));
    refreshLists(ref);
  }

  Future<void> _openFolders() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const FolderManageScreen()));
    refreshLists(ref);
    // 보고 있던 폴더가 지워졌으면 전체로 돌아간다.
    final folders = await ref.read(folderRepositoryProvider).all();
    if (_folder > noFolder && !folders.any((f) => f.id == _folder)) {
      setState(() => _folder = allFolders);
    }
  }

  Future<void> _view(Script s) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => ScriptDetailScreen(script: s)));
    refreshLists(ref);
  }

  Future<void> _duplicate(Script s) async {
    await ref.read(scriptRepositoryProvider).duplicate(s);
    refreshLists(ref);
  }

  Future<void> _move(Script s, List<Folder> folders) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('폴더 이동'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, noFolder),
            child: const Text('폴더 없음'),
          ),
          for (final f in folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, f.id),
              child: Text(f.name),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await ref
        .read(scriptRepositoryProvider)
        .moveToFolder(s.id!, picked == noFolder ? null : picked);
    refreshLists(ref);
  }

  Future<void> _delete(Script s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('원고를 지울까요?'),
        content: const Text('이 원고로 연습한 녹음과 메모도 모두 지워지고 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('지우기')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(scriptRepositoryProvider).delete(s.id!);
    refreshLists(ref);
  }

  @override
  Widget build(BuildContext context) {
    final scripts = ref.watch(scriptsProvider);
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final names = {for (final f in folders) f.id: f.name};

    return Scaffold(
      appBar: AppBar(
        title: const Text('원고관리'),
        actions: [
          IconButton(
            tooltip: '폴더 관리',
            icon: const Icon(Icons.folder_outlined),
            onPressed: _openFolders,
          ),
        ],
      ),
      floatingActionButton: scripts.value?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.content_paste),
              label: const Text('원고 추가'),
            )
          : null,
      body: switch (scripts) {
        AsyncData(:final value) when value.isEmpty => _EmptyGuide(onPaste: _add),
        AsyncData(:final value) => Column(
            children: [
              FolderChips(
                folders: folders,
                selected: _folder,
                onSelected: (v) => setState(() => _folder = v),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    for (final s in value.where((s) => inFolder(s, _folder)))
                      ListTile(
                        title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text([
                          '${countSyllables(s.body)}음절',
                          if (names[s.folderId] != null) names[s.folderId]!,
                        ].join(' · ')),
                        onTap: () => _view(s),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (v) => switch (v) {
                            'view' => _view(s),
                            'copy' => _duplicate(s),
                            'move' => _move(s, folders),
                            _ => _delete(s),
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'view', child: Text('조회')),
                            PopupMenuItem(value: 'copy', child: Text('복제')),
                            PopupMenuItem(value: 'move', child: Text('폴더 이동')),
                            PopupMenuItem(value: 'delete', child: Text('삭제')),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        AsyncError() => const Center(child: Text('원고를 불러오지 못했어요')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EmptyGuide extends StatelessWidget {
  const _EmptyGuide({required this.onPaste});
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.article_outlined, size: 64, color: Palette.ink),
            const SizedBox(height: 16),
            Text('연습할 원고를 붙여넣어 주세요',
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('뉴스 원고나 직접 쓴 글을 복사해서 붙여넣으면\n소리 내어 읽으며 연습할 수 있어요.',
                style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPaste,
              icon: const Icon(Icons.content_paste),
              label: const Text('원고 붙여넣기'),
            ),
          ],
        ),
      ),
    );
  }
}
