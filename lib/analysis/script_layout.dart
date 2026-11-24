import 'read_aloud.dart';

/// 어절 사이 끊어 읽기 표시. [pause]는 `/`(쉼), [breath]는 `//`(숨).
enum Pause { none, pause, breath }

/// 누를 때마다 없음 → / → // → 없음.
Pause cyclePause(Pause p) => switch (p) {
      Pause.none => Pause.pause,
      Pause.pause => Pause.breath,
      Pause.breath => Pause.none,
    };

/// 원고 본문을 공백으로 나눈 어절. 원고 비교(compare.dart)와 같은 규칙이다.
List<String> scriptWords(String body) =>
    body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

final _closing = RegExp('[\'"”’)\\]」』》〉]+\$');
const _pauseEnds = {',', '，', '、'};
const _breathEnds = {'.', '?', '!', '。', '？', '！'};

/// 문장부호로 자동 표시를 만든다: 쉼표 뒤 `/`, 마침표·물음표·느낌표 뒤 `//`.
Map<int, Pause> autoPauses(List<String> words) {
  final out = <int, Pause>{};
  for (var i = 0; i < words.length; i++) {
    final w = words[i].replaceFirst(_closing, '');
    if (w.isEmpty) continue;
    final last = w[w.length - 1];
    if (_breathEnds.contains(last)) {
      out[i] = Pause.breath;
    } else if (_pauseEnds.contains(last)) {
      out[i] = Pause.pause;
    }
  }
  return out;
}

/// 원고 한 줄: 어절 [start]부터 [end] 앞까지. [endPause]는 줄 끝 표시.
class ScriptLine {
  const ScriptLine(this.start, this.end, this.endPause);
  final int start;
  final int end;
  final Pause endPause;

  @override
  String toString() => 'ScriptLine($start..$end, ${endPause.name})';
}

/// 끊어 읽기 표시 뒤에서 줄을 나눈다. 표시가 없는 긴 구간은 화면에서 줄바꿈한다.
List<ScriptLine> layoutLines(int wordCount, Map<int, Pause> pauses) {
  final lines = <ScriptLine>[];
  var start = 0;
  for (var i = 0; i < wordCount; i++) {
    final p = pauses[i] ?? Pause.none;
    if (p != Pause.none && i < wordCount - 1) {
      lines.add(ScriptLine(start, i + 1, p));
      start = i + 1;
    }
  }
  if (start < wordCount) {
    lines.add(ScriptLine(start, wordCount, pauses[wordCount - 1] ?? Pause.none));
  }
  return lines;
}

final _unit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// 읽는 소리로 바꾼 뒤의 글자 목록 (공백·문장부호 제외). 원고 비교와 같은 단위.
List<String> readUnits(String text) =>
    readAloud(text).split('').where(_unit.hasMatch).toList();

/// 어절 i가 시작하기 전까지의 읽는 소리 글자 수. 길이는 어절 수 + 1.
List<int> syllableOffsets(List<String> words) {
  final out = [0];
  for (final w in words) {
    out.add(out.last + readUnits(w).length);
  }
  return out;
}
