import 'script_layout.dart';

/// 기본 속도: 1분당 350음절 (방송 뉴스 낭독 보통 330~370).
const defaultPace = 350.0;
const minPace = 200.0;
const maxPace = 500.0;
const paceStep = 10.0;

/// `/`(쉼), `//`(숨) 뒤에 멈추는 시간.
const pauseGap = Duration(milliseconds: 300);
const breathGap = Duration(milliseconds: 600);

/// 녹음 버튼을 누른 뒤 진행이 시작되기까지 (3-2-1).
const countdownLength = Duration(seconds: 3);

/// 마지막 문장이 끝난 뒤 녹음을 멈추기까지.
const endHold = Duration(milliseconds: 1500);

/// 범위(200~500) 안의 10 단위 값으로 맞춘다.
double clampPace(double v) {
  if (v.isNaN) return defaultPace;
  final stepped = (v / paceStep).round() * paceStep;
  return stepped.clamp(minPace, maxPace).toDouble();
}

/// `//`(숨) 표시에서만 나눈 문장들.
List<ScriptLine> sentencesOf(int wordCount, Map<int, Pause> pauses) => layoutLines(wordCount, {
      for (final e in pauses.entries)
        if (e.value == Pause.breath) e.key: Pause.breath,
    });

/// 진행 시간 t에서의 상태.
class KaraokeFrame {
  const KaraokeFrame({
    required this.word,
    required this.wordFill,
    required this.sentence,
    required this.position,
    required this.progress,
    required this.remaining,
    required this.done,
  });

  /// 지금 채우는 어절과 그 어절을 채운 비율(0~1).
  final int word;
  final double wordFill;

  /// 지금 문장 번호 ([sentencesOf] 기준).
  final int sentence;

  /// 원고에서 채운 위치(읽는 소리 단위)와 비율.
  final int position;
  final double progress;
  final Duration remaining;

  /// 마지막 어절과 쉬는 시간까지 끝났으면 true.
  final bool done;
}

/// 정해진 속도로 원고를 채워 가는 시간표.
/// 어절마다 (읽는 소리 음절 수 × 60 ÷ 속도)초 동안 채우고, 표시가 있으면 그만큼 쉰다.
class KaraokeTimeline {
  KaraokeTimeline(List<String> words, Map<int, Pause> pauses, double pace)
      : _offsets = syllableOffsets(words),
        _sentences = sentencesOf(words.length, pauses) {
    final perUnit = Duration(microseconds: (60e6 / clampPace(pace)).round());
    var t = Duration.zero;
    for (var i = 0; i < words.length; i++) {
      final units = _offsets[i + 1] - _offsets[i];
      _starts.add(t);
      _speak.add(perUnit * units);
      t += perUnit * units;
      t += switch (pauses[i] ?? Pause.none) {
        Pause.none => Duration.zero,
        Pause.pause => pauseGap,
        Pause.breath => breathGap,
      };
    }
    // 음절이 하나도 없으면(빈 원고, 기호만) 쉴 것도 없다.
    total = _offsets.last == 0 ? Duration.zero : t;
  }

  final List<int> _offsets;
  final List<ScriptLine> _sentences;
  final _starts = <Duration>[];
  final _speak = <Duration>[];
  late final Duration total;

  int get _units => _offsets.last;

  int _sentenceOf(int word) {
    for (var s = 0; s < _sentences.length; s++) {
      if (word < _sentences[s].end) return s;
    }
    return _sentences.isEmpty ? 0 : _sentences.length - 1;
  }

  KaraokeFrame at(Duration t) {
    final last = _starts.isEmpty ? 0 : _starts.length - 1;
    if (total == Duration.zero || t >= total) {
      return KaraokeFrame(
        word: last,
        wordFill: 1,
        sentence: _sentenceOf(last),
        position: _units,
        progress: 1,
        remaining: Duration.zero,
        done: true,
      );
    }
    if (t < Duration.zero) {
      return KaraokeFrame(
        word: 0,
        wordFill: 0,
        sentence: 0,
        position: 0,
        progress: 0,
        remaining: total,
        done: false,
      );
    }
    var i = 0;
    while (i < last && _starts[i + 1] <= t) {
      i++;
    }
    final speak = _speak[i];
    final into = t - _starts[i];
    final fill = speak == Duration.zero
        ? 1.0
        : (into.inMicroseconds / speak.inMicroseconds).clamp(0.0, 1.0);
    final units = _offsets[i + 1] - _offsets[i];
    // 마이크로초 반올림 오차로 경계에서 한 음절 덜 세지 않게 여유를 둔다.
    final position = _offsets[i] + (fill * units + 1e-3).floor();
    return KaraokeFrame(
      word: i,
      wordFill: fill,
      sentence: _sentenceOf(i),
      position: position,
      progress: _units == 0 ? 1 : position / _units,
      remaining: total - t,
      done: false,
    );
  }
}
