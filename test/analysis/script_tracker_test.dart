import 'package:announcer_app/analysis/script_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

const script = '시청자 여러분, 안녕하십니까. 11월 23일, 9시 뉴스를 시작하겠습니다.';
// 단위: 시청자3 여러분3 안녕하십니까6 =12, 십일월3 =15, 이십삼일4 =19, 구시2 =21, 뉴스를3 =24, 시작하겠습니다7 =31

void main() {
  test('들린 글 끝이 원고 어디인지 찾는다', () {
    final t = ScriptTracker(script);
    expect(t.total, 31);
    t.onHeard('시청자 여러분 안녕하십니까');
    expect(t.position, closeTo(12, 1));
    t.onHeard('시청자 여러분 안녕하십니까. 십일월 이십삼일');
    expect(t.position, closeTo(19, 1));
    expect(t.progress, closeTo(19 / 31, 0.04));
  });

  test('위치는 뒤로 가지 않는다', () {
    final t = ScriptTracker(script)..onHeard('시청자 여러분 안녕하십니까 십일월');
    final before = t.position;
    t.onHeard('시청자 여러분');
    expect(t.position, before);
  });

  test('조금 틀리게 들려도 따라간다', () {
    final t = ScriptTracker(script)..onHeard('시청자 여러분 안녕하십니가 십일월 이십삼일 구시 뉴스를');
    expect(t.position, closeTo(24, 1));
  });

  test('숫자 표기 차이는 같은 것으로 본다', () {
    final t = ScriptTracker('2026년 경제 전망')..onHeard('이천이십육년 경제 전망');
    expect(t.position, t.total);
  });

  test('원고와 무관한 글은 위치를 움직이지 않는다 (Review Focus 2)', () {
    final t = ScriptTracker(script)..onHeard('오늘 날씨는 맑겠습니다');
    expect(t.position, 0);
  });

  test('30단위 넘게 앞으로 튀면 두 번 연속 같을 때만 받아들인다', () {
    final long = '${List.filled(6, '경제가 크게 성장했습니다.').join(' ')} 마지막 문장입니다.';
    final t = ScriptTracker(long);
    final far = '${List.filled(6, '경제가 크게 성장했습니다').join(' ')} 마지막';
    t.onHeard(far);
    expect(t.position, 0);
    t.onHeard('$far 문장');
    expect(t.position, greaterThan(60));
  });

  test('추정 위치는 원고 끝을 넘지 않고 뒤로 가지 않는다', () {
    final t = ScriptTracker(script)..onEstimate(10);
    expect(t.position, 10);
    t.onEstimate(5);
    expect(t.position, 10);
    t.onEstimate(500);
    expect(t.position, 31);
  });

  test('빈 원고는 진행 0', () {
    final t = ScriptTracker('')..onHeard('아무 말');
    expect(t.total, 0);
    expect(t.progress, 0);
  });
}
