import 'dart:typed_data';

/// 한 시점의 목소리 높이. 무성(목소리 없음) 구간은 [hz]가 null이다.
class PitchPoint {
  const PitchPoint({required this.t, required this.hz});
  final Duration t;
  final double? hz;

  @override
  String toString() => 'PitchPoint(${t.inMilliseconds}ms, $hz)';
}

// YIN 설정 (Task 6 계획 값)
const _window = Duration(milliseconds: 40);
const _threshold = 0.15;
const _minHz = 70.0;
const _maxHz = 500.0;

/// 이 값보다 조용한 프레임은 무성으로 본다 (RMS, -1~1 범위 샘플 기준).
const _silenceRms = 0.01;

/// YIN으로 [hop] 간격마다 음높이를 구한다. [samples]는 -1~1 범위 모노 PCM.
List<PitchPoint> analyzePitch(
  Float32List samples, {
  int sampleRate = 16000,
  Duration hop = const Duration(milliseconds: 10),
}) {
  final w = sampleRate * _window.inMicroseconds ~/ Duration.microsecondsPerSecond;
  final hopN = sampleRate * hop.inMicroseconds ~/ Duration.microsecondsPerSecond;
  final minTau = (sampleRate / _maxHz).floor();
  final maxTau = (sampleRate / _minHz).ceil();
  final points = <PitchPoint>[];
  final d = Float64List(maxTau + 1);

  for (var k = 0, s = 0; s + w + maxTau <= samples.length; k++, s += hopN) {
    points.add(PitchPoint(
      t: hop * k,
      hz: _yinFrame(samples, s, w, minTau, maxTau, d, sampleRate),
    ));
  }
  return points;
}

double? _yinFrame(Float32List x, int s, int w, int minTau, int maxTau,
    Float64List d, int sampleRate) {
  var energy = 0.0;
  for (var j = 0; j < w; j++) {
    energy += x[s + j] * x[s + j];
  }
  if (energy / w < _silenceRms * _silenceRms) return null;

  // 차이 함수와 누적 평균 정규화 (CMND)
  d[0] = 1;
  var running = 0.0;
  for (var tau = 1; tau <= maxTau; tau++) {
    var sum = 0.0;
    for (var j = 0; j < w; j++) {
      final diff = x[s + j] - x[s + j + tau];
      sum += diff * diff;
    }
    running += sum;
    d[tau] = running == 0 ? 1 : sum * tau / running;
  }

  for (var tau = minTau; tau <= maxTau; tau++) {
    if (d[tau] < _threshold) {
      while (tau + 1 <= maxTau && d[tau + 1] < d[tau]) {
        tau++;
      }
      final refined = _parabolic(d, tau, maxTau);
      final hz = sampleRate / refined;
      return (hz >= _minHz && hz <= _maxHz) ? hz : null;
    }
  }
  return null;
}

double _parabolic(Float64List d, int tau, int maxTau) {
  if (tau <= 1 || tau >= maxTau) return tau.toDouble();
  final a = d[tau - 1], b = d[tau], c = d[tau + 1];
  final denom = a - 2 * b + c;
  if (denom == 0) return tau.toDouble();
  return tau + 0.5 * (a - c) / denom;
}
