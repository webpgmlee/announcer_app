// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../analysis/error_stats.dart';
import '../data/models.dart';
import '../theme.dart';

/// 메모 창에서 저장한 내용. 글이 비어 있으면 메모를 지운다는 뜻이다.
class MemoEdit {
  const MemoEdit(this.kind, this.text);
  final MemoKind kind;
  final String text;
}

final _trailingMarks = RegExp('[\\s.,!?…\'"”’)\\]」』]+\$');

/// 어절 하나의 메모 창 (시안 2 아래). 저장하면 [MemoEdit], 닫으면 null.
Future<MemoEdit?> showMemoSheet(
  BuildContext context, {
  required String word,
  required int wordIndex,
  required WordErrorStats stats,
  Memo? memo,
}) =>
    showModalBottomSheet<MemoEdit>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MemoSheet(
        word: word.replaceFirst(_trailingMarks, ''),
        wrong: stats.wrong[wordIndex] ?? 0,
        recognized: stats.recognized,
        memo: memo,
      ),
    );

class _MemoSheet extends StatefulWidget {
  const _MemoSheet({
    required this.word,
    required this.wrong,
    required this.recognized,
    this.memo,
  });
  final String word;
  final int wrong;
  final int recognized;
  final Memo? memo;

  @override
  State<_MemoSheet> createState() => _MemoSheetState();
}

class _MemoSheetState extends State<_MemoSheet> {
  late MemoKind _kind = widget.memo?.kind ?? MemoKind.pronunciation;
  late final _text = TextEditingController(text: widget.memo?.text ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('길게 눌러 메모', style: TextStyle(color: Palette.faint, fontSize: 14)),
          const SizedBox(height: 4),
          Text(widget.word, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w300)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final k in MemoKind.values)
                _KindChip(
                  label: k.label,
                  selected: k == _kind,
                  onTap: () => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: widget.memo == null,
            cursorColor: Palette.red,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              hintText: '예: 받침 또렷하게',
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Palette.line)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Palette.ink)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.recognized > 0)
                Text('녹음 ${widget.recognized}번 중 ${widget.wrong}번 틀림',
                    style: const TextStyle(color: Palette.muted)),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
                onPressed: () => Navigator.pop(context, MemoEdit(_kind, _text.text.trim())),
                child: const Text('저장', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Palette.memo : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? Palette.red : Palette.line, width: 1.4),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 16, color: selected ? Palette.memoText : Palette.muted)),
        ),
      );
}
