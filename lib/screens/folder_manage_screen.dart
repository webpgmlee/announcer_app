// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/folder_repository.dart';
import '../data/models.dart';
import '../providers.dart';
import '../theme.dart';

/// 폴더 관리: 추가, 이름 수정, 삭제 (안의 원고는 폴더 없음으로).
class FolderManageScreen extends ConsumerWidget {
  const FolderManageScreen({super.key});

  /// 이름 입력 창. [save]가 ArgumentError를 던지면 창 안에 이유를 보여준다.
  Future<void> _nameDialog(
    BuildContext context, {
    required String title,
    String initial = '',
    required Future<void> Function(String) save,
  }) => showDialog<void>(
    context: context,
    builder: (_) => _NameDialog(title: title, initial: initial, save: save),
  );

  Future<void> _delete(BuildContext context, WidgetRef ref, Folder f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('폴더를 지울까요?'),
        content: const Text('안의 원고는 지워지지 않고 폴더 없음으로 옮겨져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(folderRepositoryProvider).delete(f.id!);
    refreshLists(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider);
    final repo = ref.read(folderRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('폴더 관리')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nameDialog(
          context,
          title: '폴더 추가',
          save: (name) async {
            await repo.add(name);
            refreshLists(ref);
          },
        ),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('폴더 추가'),
      ),
      body: switch (folders) {
        AsyncData(:final value) when value.isEmpty => const Center(
          child: Text(
            '아직 폴더가 없어요',
            style: TextStyle(fontSize: 16, color: Palette.muted),
          ),
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final f in value)
              if (isDefaultFolder(f))
                // 기본 폴더(경제·시사·연예·스포츠)는 이름을 바꾸거나 지울 수 없다.
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(f.name),
                  subtitle: const Text(
                    '기본 폴더',
                    style: TextStyle(color: Palette.faint),
                  ),
                  trailing: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.lock_outline,
                      color: Palette.faint,
                      size: 20,
                    ),
                  ),
                )
              else
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(f.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '이름 바꾸기',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _nameDialog(
                          context,
                          title: '이름 바꾸기',
                          initial: f.name,
                          save: (name) async {
                            await repo.rename(f.id!, name);
                            refreshLists(ref);
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: '폴더 지우기',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, f),
                      ),
                    ],
                  ),
                ),
          ],
        ),
        AsyncError() => const Center(child: Text('폴더를 불러오지 못했어요')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initial,
    required this.save,
  });
  final String title;
  final String initial;
  final Future<void> Function(String) save;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      await widget.save(_text.text);
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _text,
      autofocus: true,
      decoration: InputDecoration(hintText: '폴더 이름', errorText: _error),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      TextButton(onPressed: _submit, child: const Text('확인')),
    ],
  );
}
