// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/syllables.dart';
import '../data/models.dart';
import '../providers.dart';
import 'script_edit_screen.dart';

/// 원고를 눌렀을 때 열 화면. app에서 연습 화면으로 연결한다.
typedef ScriptOpener = void Function(BuildContext context, Script script);

class ScriptListScreen extends ConsumerStatefulWidget {
  const ScriptListScreen({super.key, this.onOpen});
  final ScriptOpener? onOpen;

  @override
  ConsumerState<ScriptListScreen> createState() => _ScriptListScreenState();
}

class _ScriptListScreenState extends ConsumerState<ScriptListScreen> {
  /// 밀어서 지운 원고. 목록이 다시 불러와지기 전에 바로 화면에서 뺀다
  /// (Dismissible은 지운 뒤 곧바로 트리에서 빠져야 한다).
  final _removed = <int>{};

  Future<void> _add() => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ScriptEditScreen()));

  Future<void> _delete(Script s) async {
    setState(() => _removed.add(s.id!));
    if (ref.read(currentScriptProvider)?.id == s.id) {
      ref.read(currentScriptProvider.notifier).select(null);
    }
    await ref.read(scriptRepositoryProvider).delete(s.id!);
    ref.invalidate(scriptsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final scripts = ref.watch(scriptsProvider);
    final visible = scripts.value?.where((s) => !_removed.contains(s.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('내 원고')),
      floatingActionButton: visible?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.content_paste),
              label: const Text('원고 추가'),
            )
          : null,
      body: switch (scripts) {
        AsyncData() when visible!.isEmpty => _EmptyGuide(onPaste: _add),
        AsyncData() => ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: visible!.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _ScriptTile(
              script: visible[i],
              onTap: widget.onOpen == null
                  ? null
                  : () => widget.onOpen!(context, visible[i]),
              onDelete: () => _delete(visible[i]),
            ),
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
            Icon(Icons.article_outlined, size: 64, color: theme.colorScheme.primary),
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

class _ScriptTile extends StatelessWidget {
  const _ScriptTile({required this.script, required this.onDelete, this.onTap});
  final Script script;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  Future<bool> _confirmDelete(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('원고를 지울까요?'),
          content: const Text('이 원고로 연습한 녹음과 기록도 모두 지워져요.'),
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
  Widget build(BuildContext context) => Dismissible(
        key: ValueKey(script.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Theme.of(context).colorScheme.errorContainer,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete_outline),
        ),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) => onDelete(),
        child: ListTile(
          title: Text(script.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${countSyllables(script.body)}음절'),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
