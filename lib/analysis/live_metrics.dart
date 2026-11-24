import 'dart:math';
import 'dart:typed_data';

// 판단 기준값 (스펙 3.2: 초기값, 나중에 조정)
/// 1분당 음절이 이보다 적으면 느림.
const slowSpm = 280.0;

/// 1분당 음절이 이보다 많으면 빠름.
const fastSpm = 380.0;

/// 이보다 작으면 "작게" (dBFS).
const quietDb = -30.0;

/// 이보다 크면 "크게" (dBFS).
const loudDb = -10.0;

/// 속도를 아직 모를 때 쓰는 1분당 음절 (뉴스 낭독 보통 속도).
const defaultSpm = 350.0;

/// 속도를 계산하는 최근 구간.
const speedWindow = Duration(seconds: 10);

/// 구간이 이보다 짧으면 속도를 모른다고 본다.
const minSpeedSpan = Duration(seconds: 3);

enum SpeedLevel { slow, ok, fast }

enum LoudLevel { quiet, ok, loud }

SpeedLevel speedLevel(double spm) => spm < slowSpm
    ? SpeedLevel.slow
    : spm > fastSpm
        ? SpeedLevel.fast
        : SpeedLevel.ok;

/// 샘플의 소리 크기(dBFS). 무음이나 빈 입력은 -120.
double dbfs(Float32List s) {
  if (s.isEmpty) return -120;
  var sum = 0.0;
  for (final v in s) {
    sum += v * v;
  }
  final rms = sqrt(sum / s.length);
  if (rms <= 1e-6) return -120;
  return 20 * log(rms) / ln10;
}

LoudLevel loudLevel(double db) => db < quietDb
    ? LoudLevel.quiet
    : db > loudDb
        ? LoudLevel.loud
        : LoudLevel.ok;

/// 원고 위치의 변화로 최근 10초의 1분당 음절을 구한다.
class SpeedMeter {
  final _samples = <(Duration, int)>[];

  void add(Duration t, int position) {
    _samples.add((t, position));
    while (_samples.length > 2 && t - _samples[1].$1 >= speedWindow) {
      _samples.removeAt(0);
    }
  }

  double? get spm {
    if (_samples.length < 2) return null;
    final (t0, p0) = _samples.first;
    final (t1, p1) = _samples.last;
    final span = t1 - t0;
    if (span < minSpeedSpan) return null;
    return (p1 - p0) * 60 * Duration.microsecondsPerSecond / span.inMicroseconds;
  }
}

/// 남은 음절을 지금 속도로 읽을 때 걸리는 시간. 속도를 모르면 [defaultSpm].
Duration remainingTime(int remainingUnits, double? spm) {
  final rate = (spm == null || spm <= 0) ? defaultSpm : spm;
  if (remainingUnits <= 0) return Duration.zero;
  return Duration(
      microseconds: (remainingUnits * 60 * Duration.microsecondsPerSecond / rate).round());
}
