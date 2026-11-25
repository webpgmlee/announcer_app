import 'dart:math';
import 'dart:typed_data';

import 'package:announcer_app/analysis/syllable_rate.dart';
import 'package:flutter_test/flutter_test.dart';

/// [spm] 빠르기로 음절 같은 소리 덩어리가 이어지는 합성 소리.
/// 덩어리마다 앞 60%는 소리(부드럽게 커졌다 작아짐), 뒤 40%는 아주 작은 소리.
Float32List bursts(double spm, Duration length, {double amp = 0.3}) {
  const sr = 16000;
  final n = sr * length.inMilliseconds ~/ 1000;
  final period = sr * 60 / spm;
  return Float32List.fromList(List.generate(n, (i) {
    final phase = (i % period) / period;
    final env = phase < 0.6 ? sin(pi * phase / 0.6) : 0.0;
    return amp * env * sin(2 * pi * 180 * i / sr);
  }));
}

/// 프레임(0.1초) 단위로 측정기에 넣는다.
void feed(SyllableRateMeter m, Float32List s) {
  for (var o = 0; o < s.length; o += 1600) {
    m.add(Float32List.sublistView(s, o, min(o + 1600, s.length)));
  }
}

void main() {
  group('음절 빠르기 추정', () {
    for (final spm in [250.0, 350.0, 450.0]) {
      test('${spm.round()}음절/분 소리를 ±12% 안으로 추정한다', () {
        final m = SyllableRateMeter();
        feed(m, bursts(spm, const Duration(seconds: 6)));
        expect(m.spm, isNotNull);
        expect(m.spm!, closeTo(spm, spm * 0.12));
      });
    }

    test('무음이면 모른다(null)', () {
      final m = SyllableRateMeter();
      feed(m, Float32List(16000 * 4));
      expect(m.spm, isNull);
    });

    test('말한 시간이 1.5초가 안 되면 모른다', () {
      final m = SyllableRateMeter();
      feed(m, bursts(350, const Duration(seconds: 1)));
      expect(m.spm, isNull);
    });

    test('문장 사이에 쉰 시간(0.25초 넘음)은 빠르기 계산에서 뺀다', () {
      final m = SyllableRateMeter();
      feed(m, bursts(350, const Duration(seconds: 2)));
      feed(m, Float32List(16000)); // 1초 숨
      feed(m, bursts(350, const Duration(seconds: 2)));
      expect(m.spm!, closeTo(350, 350 * 0.12));
    });

    test('최근 몇 초만 본다: 느리게 읽다가 빨라지면 빠르게 나온다', () {
      final m = SyllableRateMeter();
      feed(m, bursts(250, const Duration(seconds: 6)));
      feed(m, bursts(450, const Duration(seconds: 5)));
      expect(m.spm!, greaterThan(400));
    });
  });

  group('빠르기 알림 판단', () {
    const pace = 350.0;
    Duration ms(int v) => Duration(milliseconds: v);

    test('진행 속도와 15% 넘게 차이 나면 빨라요·느려요', () {
      expect(PaceAdvisor(pace: pace).update(ms(0), 420), PaceFeedback.fast);
      expect(PaceAdvisor(pace: pace).update(ms(0), 280), PaceFeedback.slow);
      expect(PaceAdvisor(pace: pace).update(ms(0), 390), PaceFeedback.none);
      expect(PaceAdvisor(pace: pace).update(ms(0), 310), PaceFeedback.none);
      expect(PaceAdvisor(pace: pace).update(ms(0), null), PaceFeedback.none);
    });

    test('한 번 뜨면 2초는 유지해 깜빡거리지 않는다', () {
      final a = PaceAdvisor(pace: pace);
      expect(a.update(ms(0), 450), PaceFeedback.fast);
      expect(a.update(ms(500), 350), PaceFeedback.fast);
      expect(a.update(ms(1900), 350), PaceFeedback.fast);
      expect(a.update(ms(2100), 350), PaceFeedback.none);
    });

    test('계속 빠르면 계속 빨라요, 느려지면 2초 뒤 느려요로 바뀐다', () {
      final a = PaceAdvisor(pace: pace);
      a.update(ms(0), 450);
      expect(a.update(ms(3000), 450), PaceFeedback.fast);
      expect(a.update(ms(3500), 250), PaceFeedback.fast); // 마지막으로 빨랐던 때부터 2초 전
      expect(a.update(ms(5100), 250), PaceFeedback.slow);
    });

    test('허용 폭은 15%', () => expect(paceTolerance, 0.15));
  });
}
