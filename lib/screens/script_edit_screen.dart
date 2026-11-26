// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/syllables.dart';
import '../data/models.dart';
import '../providers.dart';

/// 제목이 비어 있을 때 본문 앞부분을 몇 글자 쓸지.
const autoTitleLength = 20;

/// 제목을 비우면 본문 앞 [autoTitleLength]자를 제목으로 쓴다.
String titleFor(String title, String body) {
  if (title.trim().isNotEmpty) return title.trim();
  final flat = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  return flat.length <= autoTitleLength
      ? flat
      : flat.substring(0, autoTitleLength);
}

class ScriptEditScreen extends ConsumerStatefulWidget {
  const ScriptEditScreen({super.key, this.initialFolderId});

  /// 처음에 골라 둘 폴더 (원고관리에서 폴더를 보고 있었으면 그 폴더).
  final int? initialFolderId;

  @override
  ConsumerState<ScriptEditScreen> createState() => _ScriptEditScreenState();
}

class _ScriptEditScreenState extends ConsumerState<ScriptEditScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;
  late int? _folderId = widget.initialFolderId;

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _canSave => !_saving && _body.text.trim().isNotEmpty;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('복사한 글이 없어요')));
      }
      return;
    }
    _body.text = text;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref
        .read(scriptRepositoryProvider)
        .add(
          Script(
            title: titleFor(_title.text, _body.text),
            body: _body.text.trim(),
            folderId: _folderId,
            createdAt: DateTime.now(),
          ),
        );
    refreshLists(ref);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final syllables = countSyllables(_body.text);
    return Scaffold(
      appBar: AppBar(
        title: const Text('원고 붙여넣기'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const Key('save'),
              onPressed: _canSave ? _save : null,
              child: const Text('저장'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('title'),
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '제목 (비우면 본문 앞부분을 써요)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _FolderSelect(
                value: _folderId,
                onChanged: (v) => setState(() => _folderId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    key: const Key('paste'),
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste),
                    label: const Text('복사한 글 붙여넣기'),
                  ),
                  const Spacer(),
                  Text(
                    '$syllables음절',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  key: const Key('body'),
                  controller: _body,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: '여기에 원고를 붙여넣거나 직접 입력하세요',
                    border: OutlineInputBorder(),
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

/// 원고를 넣을 폴더 고르기 (폴더 없음 포함).
class _FolderSelect extends ConsumerWidget {
  const _FolderSelect({required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    return DropdownButtonFormField<int?>(
      key: const Key('folder-select'),
      initialValue: folders.any((f) => f.id == value) ? value : null,
      decoration: const InputDecoration(
        labelText: '폴더',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('폴더 없음')),
        for (final f in folders)
          DropdownMenuItem<int?>(value: f.id, child: Text(f.name)),
      ],
      onChanged: onChanged,
    );
  }
}
