import 'dart:math';
import 'dart:typed_data';

import 'package:announcer_app/analysis/intonation.dart';
import 'package:announcer_app/analysis/pitch.dart';
import 'package:flutter_test/flutter_test.dart';

Float32List sine(double hz, Duration d, {int sr = 16000, double amp = 0.5}) {
  final n = sr * d.inMilliseconds ~/ 1000;
  return Float32List.fromList(
      List.generate(n, (i) => amp * sin(2 * pi * hz * i / sr)));
}

void main() {
  test('200Hz 사인파 1초 → 유성 프레임은 모두 196~204Hz', () {
    final points = analyzePitch(sine(200, const Duration(seconds: 1)));
    final voiced = points.where((p) => p.hz != null).toList();
    expect(voiced.length, greaterThan(points.length * 0.8));
    for (final p in voiced) {
      expect(p.hz, inInclusiveRange(196, 204));
    }
  });

  test('120Hz 남성 음역도 잡는다', () {
    final points = analyzePitch(sine(120, const Duration(seconds: 1)));
    final voiced = points.where((p) => p.hz != null).toList();
    expect(voiced, isNotEmpty);
    for (final p in voiced) {
      expect(p.hz, inInclusiveRange(117, 123));
    }
  });

  test('프레임 간격은 10ms', () {
    final points = analyzePitch(sine(200, const Duration(milliseconds: 500)));
    expect(points[1].t - points[0].t, const Duration(milliseconds: 10));
  });

  test('무음 1초 → 모든 hz가 null, noVoice (Review Focus 1)', () {
    final points = analyzePitch(Float32List(16000));
    expect(points, isNotEmpty);
    expect(points.every((p) => p.hz == null), isTrue);
    expect(analyzeIntonation(points).noVoice, isTrue);
  });

  test('빈 입력도 죽지 않는다', () {
    expect(analyzePitch(Float32List(0)), isEmpty);
    expect(analyzeIntonation(const []).noVoice, isTrue);
  });
}
