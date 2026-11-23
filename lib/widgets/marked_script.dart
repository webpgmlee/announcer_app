// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../analysis/compare.dart';

/// 상태별 배경색. 밝은 바탕·어두운 바탕 모두에서 글자를 검게 써서 읽히게 한다.
const markColors = {
  MarkStatus.misheard: Color(0xFFFFD54F), // 노랑: 다르게 들림
  MarkStatus.missing: Color(0xFFEF9A9A), // 빨강: 빠뜨림
  MarkStatus.extra: Color(0xFF90CAF9), // 파랑: 덧붙임
};

const markLabels = {
  MarkStatus.misheard: '다르게 들림',
  MarkStatus.missing: '빠뜨림',
  MarkStatus.extra: '덧붙임',
};

/// 원고 위에 비교 결과를 칠한다. 누르면 무엇이 들렸는지 알려준다.
/// [WordMark.score]가 있으면(나중의 B 기능) 어절 아래에 숫자로 함께 표시한다.
class MarkedScript extends StatefulWidget {
  const MarkedScript({super.key, required this.marks, this.fontSize = 22});
  final List<WordMark> marks;
  final double fontSize;

  @override
  State<MarkedScript> createState() => _MarkedScriptState();
}

class _MarkedScriptState extends State<MarkedScript> {
  int? _selected;

  String? _explain(WordMark m) => switch (m.status) {
        MarkStatus.misheard => '이렇게 들렸어요: ${m.heardWord ?? ''}',
        MarkStatus.missing => '이 부분이 들리지 않았어요',
        MarkStatus.extra => '원고에 없는 말이 들렸어요: ${m.heardWord ?? ''}',
        MarkStatus.matched => null,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selected == null || _selected! >= widget.marks.length
        ? null
        : widget.marks[_selected!];
    final explanation = selected == null ? null : _explain(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          children: [
            for (final e in markLabels.entries)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                      color: markColors[e.key], borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 4),
                Text(e.value, style: theme.textTheme.bodySmall),
              ]),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: [
            for (var i = 0; i < widget.marks.length; i++)
              _MarkChip(
                key: ValueKey('mark-$i'),
                mark: widget.marks[i],
                fontSize: widget.fontSize,
                selected: _selected == i,
                onTap: widget.marks[i].status == MarkStatus.matched
                    ? null
                    : () => setState(() => _selected = _selected == i ? null : i),
              ),
          ],
        ),
        if (explanation != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(explanation, style: theme.textTheme.bodyLarge),
          ),
        ],
      ],
    );
  }
}

class _MarkChip extends StatelessWidget {
  const _MarkChip({
    super.key,
    required this.mark,
    required this.fontSize,
    required this.selected,
    this.onTap,
  });
  final WordMark mark;
  final double fontSize;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = markColors[mark.status];
    final isExtra = mark.status == MarkStatus.extra;
    final text = isExtra ? (mark.heardWord ?? '') : mark.scriptWord;
    final style = TextStyle(
      fontSize: fontSize,
      height: 1.4,
      color: color == null ? null : Colors.black87,
      decoration: mark.status == MarkStatus.missing ? TextDecoration.lineThrough : null,
      fontStyle: isExtra ? FontStyle.italic : null,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: selected ? Border.all(width: 2) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: style),
            if (mark.score != null)
              Text('${mark.score!.round()}',
                  style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
