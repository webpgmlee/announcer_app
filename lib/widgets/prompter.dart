// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../analysis/error_stats.dart';
import '../analysis/script_layout.dart';
import '../data/models.dart';
import '../theme.dart';

/// 원고를 방송 프롬프터처럼 줄 단위로 보여준다.
/// 끊어 읽기 표시(/, //), 강조, 자주 틀림, 메모를 원고 위에 함께 그린다.
class Prompter extends StatefulWidget {
  const Prompter({
    super.key,
    required this.words,
    required this.pauses,
    required this.memos,
    required this.stats,
    this.currentLine = 0,
    this.editable = false,
    this.onTapGap,
    this.onLongPressWord,
  });

  final List<String> words;
  final Map<int, Pause> pauses;
  final Map<int, Memo> memos;
  final WordErrorStats stats;

  /// 지금 읽는 줄 번호 ([layoutLines] 기준).
  final int currentLine;

  /// 녹음 중이 아닐 때만 표시를 고칠 수 있다.
  final bool editable;
  final void Function(int wordIndex)? onTapGap;
  final void Function(int wordIndex)? onLongPressWord;

  @override
  State<Prompter> createState() => _PrompterState();
}

class _PrompterState extends State<Prompter> {
  final _lineKeys = <int, GlobalKey>{};

  GlobalKey _keyFor(int line) => _lineKeys.putIfAbsent(line, GlobalKey.new);

  @override
  void didUpdateWidget(Prompter old) {
    super.didUpdateWidget(old);
    if (old.currentLine != widget.currentLine) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _lineKeys[widget.currentLine]?.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(ctx,
              alignment: 0.35, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = layoutLines(widget.words.length, widget.pauses);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var l = 0; l < lines.length; l++)
            _Line(
              key: _keyFor(l),
              index: l,
              line: lines[l],
              state: l < widget.currentLine
                  ? _LineState.past
                  : l == widget.currentLine
                      ? _LineState.current
                      : _LineState.next,
              prompter: widget,
            ),
        ],
      ),
    );
  }
}

enum _LineState { past, current, next }

class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.index,
    required this.line,
    required this.state,
    required this.prompter,
  });

  final int index;
  final ScriptLine line;
  final _LineState state;
  final Prompter prompter;

  @override
  Widget build(BuildContext context) {
    final (size, color) = switch (state) {
      _LineState.past => (20.0, Palette.faint),
      _LineState.current => (30.0, Palette.ink),
      _LineState.next => (24.0, Palette.faint),
    };
    final style = TextStyle(
        fontSize: size, color: color, fontWeight: FontWeight.w300, height: 1.35);
    final hasFrequent = [
      for (var i = line.start; i < line.end; i++) prompter.stats.isFrequent(i)
    ].any((f) => f);

    return AnimatedPadding(
      key: ValueKey('line-$index-${state.name}'),
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.symmetric(vertical: state == _LineState.current ? 10 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: hasFrequent
                ? Padding(
                    padding: EdgeInsets.only(top: size * 0.6),
                    child: const CircleAvatar(radius: 3, backgroundColor: Palette.red),
                  )
                : null,
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.start,
              runSpacing: 4,
              children: [
                for (var i = line.start; i < line.end; i++) ...[
                  _Word(index: i, style: style, prompter: prompter),
                  _Gap(index: i, fontSize: size, prompter: prompter),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.index, required this.style, required this.prompter});
  final int index;
  final TextStyle style;
  final Prompter prompter;

  @override
  Widget build(BuildContext context) {
    final memo = prompter.memos[index];
    final emphasis = memo?.kind == MemoKind.emphasis;
    final wrong = prompter.stats.wrong[index] ?? 0;
    final frequent = prompter.stats.isFrequent(index);

    Widget word = Text(prompter.words[index], style: style);
    if (emphasis) {
      word = Container(
        key: ValueKey('emphasis-$index'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.transparent, Palette.emphasis, Palette.emphasis],
            stops: [0, 0.55, 0.55, 1],
          ),
        ),
        child: word,
      );
    }
    if (frequent) {
      word = Stack(
        key: ValueKey('frequent-$index'),
        clipBehavior: Clip.none,
        children: [
          CustomPaint(foregroundPainter: _WavyUnderline(), child: word),
          Positioned(
            right: -10,
            top: -6,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Palette.memo, shape: BoxShape.circle),
              child: Text('$wrong',
                  style: const TextStyle(fontSize: 11, color: Palette.red, height: 1)),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      key: ValueKey('word-$index'),
      onLongPress: prompter.editable && prompter.onLongPressWord != null
          ? () => prompter.onLongPressWord!(index)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          word,
          if (memo != null && memo.text.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: Palette.memo,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(memo.text,
                  style: const TextStyle(fontSize: 14, color: Palette.memoText)),
            ),
        ],
      ),
    );
  }
}

/// 어절 뒤 끊어 읽기 표시 자리. 누르면 표시가 바뀐다.
class _Gap extends StatelessWidget {
  const _Gap({required this.index, required this.fontSize, required this.prompter});
  final int index;
  final double fontSize;
  final Prompter prompter;

  @override
  Widget build(BuildContext context) {
    final p = prompter.pauses[index] ?? Pause.none;
    final mark = switch (p) {
      Pause.none => '',
      Pause.pause => '/',
      Pause.breath => '//',
    };
    return GestureDetector(
      key: ValueKey('gap-$index'),
      behavior: HitTestBehavior.opaque,
      onTap: prompter.editable && prompter.onTapGap != null
          ? () => prompter.onTapGap!(index)
          : null,
      child: Container(
        // alignment를 주면 Wrap 안에서 한 줄 전체로 늘어나므로 주지 않는다.
        constraints: BoxConstraints(minWidth: fontSize * 0.55),
        padding: EdgeInsets.symmetric(horizontal: mark.isEmpty ? 0 : fontSize * 0.2),
        child: Text(mark,
            style: TextStyle(
                fontSize: fontSize,
                color: Palette.red.withValues(alpha: 0.75),
                fontWeight: FontWeight.w200,
                height: 1.35)),
      ),
    );
  }
}

class _WavyUnderline extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.red
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final y = size.height - 2;
    final path = Path()..moveTo(0, y);
    const wave = 8.0;
    for (var x = 0.0; x < size.width; x += wave) {
      path.quadraticBezierTo(x + wave / 4, y + 3, x + wave / 2, y);
      path.quadraticBezierTo(x + wave * 3 / 4, y - 3, x + wave, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
