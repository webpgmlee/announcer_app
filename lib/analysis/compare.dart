import 'dart:typed_data';

import 'read_aloud.dart';

enum MarkStatus { matched, misheard, missing, extra }

/// 원고 어절 하나(또는 덧붙인 말 하나)의 비교 결과.
class WordMark {
  const WordMark({
    required this.scriptWord,
    this.heardWord,
    required this.status,
    this.score,
  });

  /// 원고에 적힌 그대로의 어절. [MarkStatus.extra]이면 빈 문자열.
  final String scriptWord;

  /// 인식된 말. [MarkStatus.matched], [MarkStatus.missing]이면 null.
  final String? heardWord;
  final MarkStatus status;

  /// 단어별 점수(0~100). 나중에 B 기능이 채운다. v1은 항상 null.
  final double? score;

  @override
  String toString() => 'WordMark($scriptWord, $heardWord, ${status.name})';
}

class _Unit {
  const _Unit(this.char, this.word);
  final String char;
  final int word;
}

enum _Op { match, sub, del, ins }

class _Step {
  const _Step(this.op, this.s, this.h);
  final _Op op;
  final int s; // 원고 단위 위치 (ins면 -1)
  final int h; // 인식 단위 위치 (del이면 -1)
}

final _unitChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// 어절 목록을 읽는 소리 기준 글자 단위로 펼친다. 공백과 문장부호는 버린다.
List<_Unit> _units(List<String> words) => [
      for (var w = 0; w < words.length; w++)
        for (final c in readAloud(words[w]).split(''))
          if (_unitChar.hasMatch(c)) _Unit(c, w),
    ];

List<String> _words(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// 원고와 인식 결과를 맞춰 본다. 띄어쓰기와 숫자·영어 표기 차이는 무시한다.
List<WordMark> compareToScript(String script, String transcript) {
  final scriptWords = _words(script);
  if (scriptWords.isEmpty) return const [];
  final heardWords = _words(transcript);
  final s = _units(scriptWords);
  final h = _units(heardWords);
  final steps = _align(s, h);

  // 원고 어절별 집계
  final total = List.filled(scriptWords.length, 0);
  final matched = List.filled(scriptWords.length, 0);
  final deleted = List.filled(scriptWords.length, 0);
  final insideIns = List.filled(scriptWords.length, 0);
  final heard = List.generate(scriptWords.length, (_) => StringBuffer());
  for (final u in s) {
    total[u.word]++;
  }

  // 덧붙인 말: (다음 원고 어절 위치, 인식 어절 번호, 글자)
  final extras = <({int before, int heardWord, StringBuffer text})>[];

  // 각 단계 앞뒤의 원고 어절을 미리 구한다.
  final prevWord = List.filled(steps.length, -1);
  final nextWord = List.filled(steps.length, -1);
  for (var k = 0, last = -1; k < steps.length; k++) {
    prevWord[k] = last;
    if (steps[k].op != _Op.ins) last = s[steps[k].s].word;
  }
  for (var k = steps.length - 1, next = -1; k >= 0; k--) {
    nextWord[k] = next;
    if (steps[k].op != _Op.ins) next = s[steps[k].s].word;
  }

  for (var k = 0; k < steps.length; k++) {
    final st = steps[k];
    switch (st.op) {
      case _Op.match:
        matched[s[st.s].word]++;
        heard[s[st.s].word].write(h[st.h].char);
      case _Op.sub:
        heard[s[st.s].word].write(h[st.h].char);
      case _Op.del:
        deleted[s[st.s].word]++;
      case _Op.ins:
        if (prevWord[k] != -1 && prevWord[k] == nextWord[k]) {
          insideIns[prevWord[k]]++;
          heard[prevWord[k]].write(h[st.h].char);
        } else {
          final before = nextWord[k] == -1 ? scriptWords.length : nextWord[k];
          final hw = h[st.h].word;
          if (extras.isNotEmpty &&
              extras.last.before == before &&
              extras.last.heardWord == hw) {
            extras.last.text.write(h[st.h].char);
          } else {
            extras.add((before: before, heardWord: hw, text: StringBuffer(h[st.h].char)));
          }
        }
    }
  }

  final out = <WordMark>[];
  void emitExtrasBefore(int w) {
    for (final e in extras.where((e) => e.before == w)) {
      out.add(WordMark(scriptWord: '', heardWord: e.text.toString(), status: MarkStatus.extra));
    }
  }

  for (var w = 0; w < scriptWords.length; w++) {
    emitExtrasBefore(w);
    final MarkStatus status;
    if (total[w] == 0 || (matched[w] == total[w] && insideIns[w] == 0)) {
      status = MarkStatus.matched;
    } else if (deleted[w] == total[w] && insideIns[w] == 0) {
      status = MarkStatus.missing;
    } else {
      status = MarkStatus.misheard;
    }
    out.add(WordMark(
      scriptWord: scriptWords[w],
      heardWord: status == MarkStatus.misheard ? heard[w].toString() : null,
      status: status,
    ));
  }
  emitExtrasBefore(scriptWords.length);
  return out;
}

/// 글자 단위 편집 거리로 정렬한다.
List<_Step> _align(List<_Unit> s, List<_Unit> h) {
  final n = s.length, m = h.length, cols = m + 1;
  final dp = Int32List((n + 1) * cols);
  for (var i = 0; i <= n; i++) {
    dp[i * cols] = i;
  }
  for (var j = 0; j <= m; j++) {
    dp[j] = j;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final cost = s[i - 1].char == h[j - 1].char ? 0 : 1;
      var best = dp[(i - 1) * cols + j - 1] + cost;
      final del = dp[(i - 1) * cols + j] + 1;
      final ins = dp[i * cols + j - 1] + 1;
      if (del < best) best = del;
      if (ins < best) best = ins;
      dp[i * cols + j] = best;
    }
  }

  final steps = <_Step>[];
  var i = n, j = m;
  while (i > 0 || j > 0) {
    final here = dp[i * cols + j];
    if (i > 0 && j > 0) {
      final same = s[i - 1].char == h[j - 1].char;
      if (here == dp[(i - 1) * cols + j - 1] + (same ? 0 : 1)) {
        steps.add(_Step(same ? _Op.match : _Op.sub, i - 1, j - 1));
        i--;
        j--;
        continue;
      }
    }
    if (i > 0 && here == dp[(i - 1) * cols + j] + 1) {
      steps.add(_Step(_Op.del, i - 1, -1));
      i--;
    } else {
      steps.add(_Step(_Op.ins, -1, j - 1));
      j--;
    }
  }
  return steps.reversed.toList();
}
