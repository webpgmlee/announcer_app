import 'dart:collection';
import 'dart:math';

import 'pitch.dart';

// 판단 기준값 (스펙 8장: 초기값, 나중에 조정)
/// 이 폭(반음)보다 적게 움직이면 단조롭다고 본다.
const flatMaxSemitones = 1.0;

/// 단조로운 상태가 이 시간 이상 이어져야 표시한다.
const flatMinDuration = Duration(seconds: 3);

/// 문장 끝에서 이만큼(반음) 이상 오르면 "끝 올림"으로 본다.
const risingMinSemitones = 3.0;

/// 문장 끝 직전 이 시간 동안의 변화를 본다.
const risingWindow = Duration(milliseconds: 400);

/// 무성이 이 시간 이상 이어지면 문장이 끝났다고 본다.
const sentenceGap = Duration(milliseconds: 300);

/// 유성 시간이 이보다 짧으면 "목소리가 들리지 않음"으로 본다.
const minVoiced = Duration(milliseconds: 200);

class DurationRange {
  const DurationRange(this.start, this.end);
  final Duration start;
  final Duration end;

  @override
  String toString() => 'DurationRange(${start.inMilliseconds}..${end.inMilliseconds}ms)';
}

class IntonationReport {
  const IntonationReport({
    required this.flatRanges,
    required this.risingEnds,
    required this.noVoice,
  });
  final List<DurationRange> flatRanges;
  final List<Duration> risingEnds;
  final bool noVoice;
}

class _Voiced {
  _Voiced(this.t, this.st);
  final Duration t;
  double st; // 100Hz 기준 반음
}

IntonationReport analyzeIntonation(List<PitchPoint> pitch) {
  final hop = pitch.length > 1 ? pitch[1].t - pitch[0].t : const Duration(milliseconds: 10);
  final voicedCount = pitch.where((p) => p.hz != null).length;
  if (hop * voicedCount < minVoiced) {
    return const IntonationReport(flatRanges: [], risingEnds: [], noVoice: true);
  }

  final flat = <DurationRange>[];
  final rising = <Duration>[];
  for (final phrase in _phrases(pitch, hop)) {
    _smooth(phrase.points);
    flat.addAll(_flatRanges(phrase.points, hop));
    if (phrase.endsSentence && _risesAtEnd(phrase.points)) {
      rising.add(phrase.points.last.t);
    }
  }
  return IntonationReport(flatRanges: flat, risingEnds: rising, noVoice: false);
}

class _Phrase {
  _Phrase(this.points, this.endsSentence);
  final List<_Voiced> points;
  final bool endsSentence;
}

/// 긴 무성(sentenceGap 이상)을 경계로 유성 구간을 나눈다.
List<_Phrase> _phrases(List<PitchPoint> pitch, Duration hop) {
  final out = <_Phrase>[];
  var current = <_Voiced>[];
  var gap = 0;
  for (final p in pitch) {
    if (p.hz == null) {
      gap++;
      if (current.isNotEmpty && hop * gap >= sentenceGap) {
        out.add(_Phrase(current, true));
        current = [];
      }
      continue;
    }
    gap = 0;
    current.add(_Voiced(p.t, 12 * log(p.hz! / 100) / ln2));
  }
  if (current.isNotEmpty) out.add(_Phrase(current, false));
  return out;
}

/// 5프레임 중앙값으로 튀는 값을 누른다.
void _smooth(List<_Voiced> v) {
  final raw = v.map((e) => e.st).toList();
  for (var i = 0; i < v.length; i++) {
    final window = raw.sublist(max(0, i - 2), min(raw.length, i + 3))..sort();
    v[i].st = window[window.length ~/ 2];
  }
}

List<DurationRange> _flatRanges(List<_Voiced> v, Duration hop) {
  final out = <DurationRange>[];
  final maxQ = ListQueue<int>(), minQ = ListQueue<int>();
  var left = 0;
  for (var r = 0; r < v.length; r++) {
    while (maxQ.isNotEmpty && v[maxQ.last].st <= v[r].st) {
      maxQ.removeLast();
    }
    maxQ.addLast(r);
    while (minQ.isNotEmpty && v[minQ.last].st >= v[r].st) {
      minQ.removeLast();
    }
    minQ.addLast(r);
    while (v[maxQ.first].st - v[minQ.first].st >= flatMaxSemitones) {
      left++;
      if (maxQ.first < left) maxQ.removeFirst();
      if (minQ.first < left) minQ.removeFirst();
    }
    final start = v[left].t, end = v[r].t + hop;
    if (end - start >= flatMinDuration) {
      if (out.isNotEmpty && start <= out.last.end) {
        out[out.length - 1] = DurationRange(out.last.start, end);
      } else {
        out.add(DurationRange(start, end));
      }
    }
  }
  return out;
}

bool _risesAtEnd(List<_Voiced> v) {
  final from = v.last.t - risingWindow;
  final tail = v.where((e) => e.t > from).toList();
  if (tail.length < 6) return false;
  double mean(Iterable<_Voiced> xs) =>
      xs.map((e) => e.st).reduce((a, b) => a + b) / xs.length;
  final rise = mean(tail.skip(tail.length - 3)) - mean(tail.take(3));
  return rise >= risingMinSemitones;
}
