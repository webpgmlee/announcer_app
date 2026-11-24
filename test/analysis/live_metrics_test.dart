import 'dart:math';
import 'dart:typed_data';

import 'package:announcer_app/analysis/live_metrics.dart';
import 'package:announcer_app/audio/wav.dart';
import 'package:flutter_test/flutter_test.dart';

Float32List sine(double amp) => Float32List.fromList(
    List.generate(8000, (i) => amp * sin(2 * pi * 200 * i / 16000)));

void main() {
  test('속도 구간: 280 미만 느림, 380 초과 빠름', () {
    expect(speedLevel(279), SpeedLevel.slow);
    expect(speedLevel(280), SpeedLevel.ok);
    expect(speedLevel(380), SpeedLevel.ok);
    expect(speedLevel(381), SpeedLevel.fast);
  });

  test('소리 크기: dBFS와 구간', () {
    expect(dbfs(sine(1.0)), closeTo(-3, 0.5));
    expect(loudLevel(dbfs(sine(1.0))), LoudLevel.loud);
    expect(loudLevel(dbfs(sine(0.01))), LoudLevel.quiet);
    expect(loudLevel(dbfs(sine(0.1))), LoudLevel.ok);
    expect(dbfs(Float32List(100)), -120);
    expect(dbfs(Float32List(0)), -120);
  });

  test('최근 10초 동안 나아간 음절로 1분당 음절을 구한다', () {
    final m = SpeedMeter();
    expect(m.spm, isNull);
    m.add(Duration.zero, 0);
    m.add(const Duration(seconds: 2), 10);
    expect(m.spm, isNull); // 3초 미만은 모름
    m.add(const Duration(seconds: 10), 50);
    expect(m.spm, closeTo(300, 0.1));
  });

  test('10초보다 오래된 값은 빼고 계산한다', () {
    final m = SpeedMeter()
      ..add(Duration.zero, 0)
      ..add(const Duration(seconds: 5), 100)
      ..add(const Duration(seconds: 15), 130);
    expect(m.spm, closeTo(180, 0.1)); // 5초→15초 사이 30음절
  });

  test('남은 시간: 속도를 모르면 1분당 350음절', () {
    expect(defaultSpm, 350);
    expect(remainingTime(350, null), const Duration(minutes: 1));
    expect(remainingTime(150, 300), const Duration(seconds: 30));
    expect(remainingTime(0, 300), Duration.zero);
  });

  test('PCM16 변환', () {
    final b = toPcm16(Float32List.fromList([0, 1, -1, 2]));
    final v = ByteData.sublistView(b);
    expect(b.length, 8);
    expect(v.getInt16(0, Endian.little), 0);
    expect(v.getInt16(2, Endian.little), 32767);
    expect(v.getInt16(4, Endian.little), -32767);
    expect(v.getInt16(6, Endian.little), 32767);
  });
}
