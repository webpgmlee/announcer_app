// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/syllables.dart';
import '../data/models.dart';
import '../providers.dart';
import 'script_edit_screen.dart';

/// 원고를 눌렀을 때 열 화면. 연습 화면(Task 9)이 생기면 app에서 채운다.
typedef ScriptOpener = void Function(BuildContext context, Script script);

class ScriptListScreen extends ConsumerWidget {
  const ScriptListScreen({super.key, this.onOpen});
  final ScriptOpener? onOpen;

  Future<void> _add(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ScriptEditScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(scriptsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('내 원고')),
      floatingActionButton: scripts.value?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () => _add(context),
              icon: const Icon(Icons.content_paste),
              label: const Text('원고 추가'),
            )
          : null,
      body: switch (scripts) {
        AsyncData(:final value) when value.isEmpty =>
          _EmptyGuide(onPaste: () => _add(context)),
        AsyncData(:final value) => ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: value.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _ScriptTile(
              script: value[i],
              onTap: onOpen == null ? null : () => onOpen!(context, value[i]),
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

class _ScriptTile extends ConsumerWidget {
  const _ScriptTile({required this.script, this.onTap});
  final Script script;
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
  Widget build(BuildContext context, WidgetRef ref) => Dismissible(
        key: ValueKey(script.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Theme.of(context).colorScheme.errorContainer,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete_outline),
        ),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) async {
          await ref.read(scriptRepositoryProvider).delete(script.id!);
          ref.invalidate(scriptsProvider);
        },
        child: ListTile(
          title: Text(script.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${countSyllables(script.body)}음절'),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
