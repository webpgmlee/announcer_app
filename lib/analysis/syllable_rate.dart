import 'dart:math';
import 'dart:typed_data';

import 'live_metrics.dart';

// 소리 덩어리(음절)로 말 빠르기를 추정한다. 한국어는 대개 글자 하나가 소리 덩어리 하나다.
// 기준값은 처음 값이며 실제 목소리를 들어 보고 조정한다.
const _sampleRate = 16000;
const _frame = 160; // 10ms
const _windowFrames = 400; // 최근 4초
const _smooth = 3; // 30ms 평균
const _peakRadius = 5; // 앞뒤 50ms 안에서 가장 큼
const _minPeakGap = 10; // 음절 사이 최소 100ms (1분 600음절까지)
const _prominenceDb = 3.0; // 직전 골짜기보다 이만큼 커야 음절로 본다
const _lookBack = 15; // 골짜기를 찾는 범위 150ms
const _voiceDb = -40.0; // 이보다 크면 목소리
const _bridgeFrames = 25; // 0.25초보다 짧은 끊김은 말하는 중으로 본다
const _minSpeechFrames = 150; // 말한 시간이 1.5초는 되어야 빠르기를 낸다

/// 녹음 중 최근 몇 초의 말 빠르기(1분당 음절)를 추정한다.
/// 0.25초 넘게 쉰 시간(문장 사이 숨)은 빼고, 실제로 말한 시간 기준으로 계산한다.
class SyllableRateMeter {
  final _db = <double>[];
  Float32List _carry = Float32List(0);

  void add(Float32List samples) {
    var s = samples;
    if (_carry.isNotEmpty) {
      s = Float32List(_carry.length + samples.length)
        ..setRange(0, _carry.length, _carry)
        ..setRange(_carry.length, _carry.length + samples.length, samples);
    }
    var o = 0;
    for (; o + _frame <= s.length; o += _frame) {
      _db.add(dbfs(Float32List.sublistView(s, o, o + _frame)));
    }
    _carry = Float32List.fromList(Float32List.sublistView(s, o));
    if (_db.length > _windowFrames) _db.removeRange(0, _db.length - _windowFrames);
  }

  /// 최근 말 빠르기. 말한 시간이 너무 짧거나 무음이면 null.
  double? get spm {
    final n = _db.length;
    if (n == 0) return null;
    final s = List<double>.generate(n, (i) {
      final from = max(0, i - _smooth ~/ 2), to = min(n, i + _smooth ~/ 2 + 1);
      var sum = 0.0;
      for (var j = from; j < to; j++) {
        sum += _db[j];
      }
      return sum / (to - from);
    });

    // 말한 시간: 목소리 구간 + 그 사이의 짧은 끊김
    var speech = 0, lastVoiced = -1;
    for (var i = 0; i < n; i++) {
      if (s[i] <= _voiceDb) continue;
      if (lastVoiced >= 0) {
        final gap = i - lastVoiced - 1;
        if (gap < _bridgeFrames) speech += gap;
      }
      speech++;
      lastVoiced = i;
    }
    if (speech < _minSpeechFrames) return null;

    // 음절: 주변보다 크고, 직전 골짜기보다 충분히 큰 봉우리
    var peaks = 0, lastPeak = -_minPeakGap;
    for (var i = 0; i < n; i++) {
      if (s[i] <= _voiceDb || i - lastPeak < _minPeakGap) continue;
      var top = true;
      for (var j = max(0, i - _peakRadius); j <= min(n - 1, i + _peakRadius); j++) {
        if (s[j] > s[i] || (j < i && s[j] == s[i])) {
          top = false;
          break;
        }
      }
      if (!top) continue;
      var valley = s[i];
      for (var j = max(0, i - _lookBack); j < i; j++) {
        valley = min(valley, s[j]);
      }
      if (s[i] - valley < _prominenceDb) continue;
      peaks++;
      lastPeak = i;
    }
    final seconds = speech * _frame / _sampleRate;
    return peaks * 60 / seconds;
  }
}

enum PaceFeedback { none, fast, slow }

/// 진행 속도보다 이 비율 넘게 빠르거나 느리면 알린다.
const paceTolerance = 0.15;

/// 알림이 깜빡거리지 않도록 한 번 뜨면 유지하는 시간.
const paceFeedbackHold = Duration(seconds: 2);

/// 추정한 말 빠르기를 진행 속도와 비교해 "빨라요"·"느려요"를 정한다.
class PaceAdvisor {
  PaceAdvisor({required this.pace});
  final double pace;

  PaceFeedback _current = PaceFeedback.none;
  Duration _lastTrue = Duration.zero;

  PaceFeedback update(Duration t, double? spm) {
    final raw = spm == null
        ? PaceFeedback.none
        : spm > pace * (1 + paceTolerance)
            ? PaceFeedback.fast
            : spm < pace * (1 - paceTolerance)
                ? PaceFeedback.slow
                : PaceFeedback.none;
    final held = t - _lastTrue < paceFeedbackHold;

    if (raw == _current) {
      if (raw != PaceFeedback.none) _lastTrue = t;
    } else if (_current == PaceFeedback.none) {
      _current = raw;
      _lastTrue = t;
    } else if (!held) {
      _current = raw;
      _lastTrue = t;
    }
    return _current;
  }
}
