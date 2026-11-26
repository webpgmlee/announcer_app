import 'compare.dart';
import 'script_layout.dart';
import 'syllables.dart';

// 퍼펙트딕션 점수. 화면에는 "딕션 점수"라고 쓰고, 발음을 평가한다는 표현은 쓰지 않는다
// (폰 안의 음성 인식은 미세한 발음 차이를 잡지 못한다, v1 설계 4장).

/// 딕션 점수 = 정확도 × 0.7 + 속도 × 0.3
const accuracyWeight = 0.7;
const speedWeight = 0.3;

/// 목표 속도와 이 비율 안이면 속도 100점.
const speedFullBand = 0.05;

/// 목표 속도와 이 비율만큼 차이 나면 속도 0점.
const speedZeroBand = 0.5;

class DictionScore {
  const DictionScore({
    required this.total,
    required this.accuracy,
    required this.speed,
    required this.measuredPace,
    required this.stars,
    required this.perfect,
  });

  /// 딕션 점수 (0~100).
  final int total;

  /// 정확도: 원고 음절 중 맞게 들린 비율 (0~100, 음성 인식 기준).
  final double accuracy;

  /// 속도 점수 (0~100).
  final double speed;

  /// 실제로 읽은 빠르기 (1분당 음절).
  final double measuredPace;
  final int stars;

  /// 정확도 100이고 속도가 목표와 ±5% 안.
  final bool perfect;
}

int starsFor(int total) => total >= 95
    ? 3
    : total >= 85
        ? 2
        : total >= 70
            ? 1
            : 0;

/// 점수 계산기. 지금은 폰 안의 인식 결과로 계산하고([OnDeviceDictionScorer]),
/// 나중에 클라우드 발음 평가로 바꿔 끼울 수 있게 인터페이스로 둔다.
abstract class DictionScorer {
  DictionScore score({
    required String script,
    required String transcript,
    required Duration voiced,
    required double targetPace,
  });
}

class OnDeviceDictionScorer implements DictionScorer {
  const OnDeviceDictionScorer();

  @override
  DictionScore score({
    required String script,
    required String transcript,
    required Duration voiced,
    required double targetPace,
  }) {
    // 정확도: 원고 어절별로 맞게 들린 어절의 음절 수 / 전체 음절 수
    final words = scriptWords(script);
    final units = [for (final w in words) readUnits(w).length];
    final total = units.fold(0, (a, b) => a + b);
    var matched = 0;
    if (transcript.trim().isNotEmpty) {
      var i = 0;
      for (final m in compareToScript(script, transcript)) {
        if (m.status == MarkStatus.extra) continue;
        if (m.status == MarkStatus.matched) matched += units[i];
        i++;
      }
    }
    final accuracy = total == 0 ? 0.0 : matched * 100 / total;

    // 속도: 목표와의 차이 비율로 점수
    final pace = voiced <= Duration.zero
        ? 0.0
        : countSyllables(script) * 60e6 / voiced.inMicroseconds;
    // 시간 반올림 오차로 경계값이 살짝 어긋나지 않게 아주 작은 여유를 둔다.
    const eps = 1e-6;
    final gap = targetPace <= 0 ? 1.0 : (pace - targetPace).abs() / targetPace;
    final speed = pace == 0
        ? 0.0
        : gap <= speedFullBand + eps
            ? 100.0
            : gap >= speedZeroBand - eps
                ? 0.0
                : 100 * (speedZeroBand - gap) / (speedZeroBand - speedFullBand);

    final totalScore = (accuracyWeight * accuracy + speedWeight * speed).round();
    return DictionScore(
      total: totalScore,
      accuracy: accuracy,
      speed: speed,
      measuredPace: pace,
      stars: starsFor(totalScore),
      perfect: accuracy >= 100 && pace > 0 && gap <= speedFullBand + eps,
    );
  }
}
