import 'dart:math';

import 'package:announcer_app/analysis/intonation.dart';
import 'package:announcer_app/analysis/pitch.dart';
import 'package:flutter_test/flutter_test.dart';

const hop = Duration(milliseconds: 10);

/// 10ms 간격 음높이 열을 만든다. f(초) → Hz 또는 null.
List<PitchPoint> track(double seconds, double? Function(double s) f,
    {double startAt = 0}) {
  final n = (seconds * 100).round();
  return List.generate(n, (i) {
    final s = startAt + i / 100;
    return PitchPoint(t: hop * (startAt * 100 + i).round(), hz: f(s));
  });
}

void main() {
  test('3초 이상 변화폭 1반음 미만 → flatRanges에 들어간다', () {
    final pitch = [
      ...track(3.5, (s) => 200 + 2 * sin(s * 10)), // 약 0.17반음 흔들림
      ...track(0.5, (_) => null, startAt: 3.5),
    ];
    final r = analyzeIntonation(pitch);
    expect(r.noVoice, isFalse);
    expect(r.flatRanges, hasLength(1));
    final range = r.flatRanges.single;
    expect(range.start, lessThanOrEqualTo(const Duration(milliseconds: 100)));
    expect(range.end - range.start,
        greaterThanOrEqualTo(const Duration(seconds: 3)));
  });

  test('높낮이가 충분히 바뀌면 flatRanges가 비어 있다', () {
    final pitch = track(4, (s) => 160 + 60 * sin(s * 3));
    expect(analyzeIntonation(pitch).flatRanges, isEmpty);
  });

  test('3초보다 짧은 단조 구간은 넣지 않는다', () {
    final pitch = [
      ...track(2.5, (_) => 200),
      ...track(0.5, (_) => null, startAt: 2.5),
    ];
    expect(analyzeIntonation(pitch).flatRanges, isEmpty);
  });

  test('문장 끝 0.4초 동안 3반음 이상 오르면 risingEnds에 그 시점', () {
    final pitch = [
      ...track(1, (s) => 180 + 30 * sin(s * 6)),
      // 1.0~1.4초: 200Hz → 250Hz (약 3.9반음 상승)
      ...track(0.4, (s) => 200 + (s - 1) / 0.4 * 50, startAt: 1),
      ...track(0.5, (_) => null, startAt: 1.4),
    ];
    final r = analyzeIntonation(pitch);
    expect(r.risingEnds, hasLength(1));
    expect(r.risingEnds.single.inMilliseconds, inInclusiveRange(1300, 1450));
  });

  test('문장 끝을 내려 읽으면 risingEnds가 비어 있다', () {
    final pitch = [
      ...track(1, (s) => 220),
      ...track(0.4, (s) => 220 - (s - 1) / 0.4 * 60, startAt: 1),
      ...track(0.5, (_) => null, startAt: 1.4),
    ];
    expect(analyzeIntonation(pitch).risingEnds, isEmpty);
  });

  test('음절 사이 짧은 무성(0.3초 미만)은 문장 끝이 아니다', () {
    final pitch = [
      ...track(1, (s) => 200),
      ...track(0.4, (s) => 200 + (s - 1) / 0.4 * 50, startAt: 1),
      ...track(0.1, (_) => null, startAt: 1.4),
      ...track(1, (s) => 180, startAt: 1.5),
    ];
    expect(analyzeIntonation(pitch).risingEnds, isEmpty);
  });
}
