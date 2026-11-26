import 'package:announcer_app/analysis/diction_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scorer = OnDeviceDictionScorer();
  const script = '간장 공장 공장장은 강 공장장이다.';
  // 음절: 간장2 공장2 공장장은4 강1 공장장이다5 = 14

  Duration at(double pace, int syllables) =>
      Duration(microseconds: (syllables * 60e6 / pace).round());

  test('그대로 읽고 목표 속도에 맞으면 100점, 별 셋, PERFECT', () {
    final s = scorer.score(
        script: script, transcript: '간장 공장 공장장은 강 공장장이다', voiced: at(300, 14), targetPace: 300);
    expect(s.accuracy, 100);
    expect(s.speed, 100);
    expect(s.total, 100);
    expect(s.stars, 3);
    expect(s.perfect, isTrue);
    expect(s.measuredPace, closeTo(300, 0.5));
  });

  test('한 어절이 다르게 들리면 그 음절만큼 정확도가 깎인다', () {
    final s = scorer.score(
        script: script, transcript: '간장 공장 공장장은 강 강장장이다', voiced: at(300, 14), targetPace: 300);
    expect(s.accuracy, closeTo(9 / 14 * 100, 0.01)); // 공장장이다(5음절) 틀림
    expect(s.perfect, isFalse);
  });

  test('속도: ±5% 안은 100점, ±50%에서 0점, 그 사이는 직선', () {
    double speed(double pace) => scorer
        .score(script: script, transcript: '간장 공장 공장장은 강 공장장이다', voiced: at(pace, 14), targetPace: 300)
        .speed;
    expect(speed(312), 100); // +4%
    expect(speed(450), 0); // +50%
    expect(speed(150), 0); // -50%
    expect(speed(345), closeTo(100 * (0.5 - 0.15) / 0.45, 0.5)); // +15%
  });

  test('딕션 점수 = 정확도 70% + 속도 30%, 반올림', () {
    final s = scorer.score(
        script: script, transcript: '간장 공장 공장장은 강 강장장이다', voiced: at(345, 14), targetPace: 300);
    expect(s.total, (0.7 * s.accuracy + 0.3 * s.speed).round());
  });

  test('별 기준: 70↑ 하나, 85↑ 둘, 95↑ 셋', () {
    expect(starsFor(69), 0);
    expect(starsFor(70), 1);
    expect(starsFor(85), 2);
    expect(starsFor(95), 3);
  });

  test('아무 말도 안 하면 0점 (Review Focus 1)', () {
    final s = scorer.score(script: script, transcript: '', voiced: Duration.zero, targetPace: 300);
    expect(s.accuracy, 0);
    expect(s.speed, 0);
    expect(s.total, 0);
    expect(s.stars, 0);
  });

  test('전혀 다른 말을 하면 정확도가 0에 가깝다 (Review Focus 2)', () {
    final s = scorer.score(
        script: script, transcript: '오늘 날씨는 맑겠습니다', voiced: at(300, 14), targetPace: 300);
    expect(s.accuracy, lessThan(20));
  });
}
