import 'package:announcer_app/analysis/compare.dart';
import 'package:flutter_test/flutter_test.dart';

List<MarkStatus> statuses(List<WordMark> marks) =>
    marks.map((m) => m.status).toList();

void main() {
  test('같은 문장 → 모두 matched', () {
    final marks = compareToScript('경제가 크게 성장했습니다.', '경제가 크게 성장했습니다');
    expect(statuses(marks), everyElement(MarkStatus.matched));
    expect(marks.map((m) => m.scriptWord), ['경제가', '크게', '성장했습니다.']);
  });

  test('다르게 들린 단어 → misheard와 들린 말', () {
    final marks = compareToScript('경제가 성장했습니다', '경제가 생장했습니다');
    expect(statuses(marks), [MarkStatus.matched, MarkStatus.misheard]);
    expect(marks[1].heardWord, '생장했습니다');
  });

  test('단어 하나 빠짐 → missing', () {
    final marks = compareToScript('경제가 크게 성장했습니다', '경제가 성장했습니다');
    expect(statuses(marks),
        [MarkStatus.matched, MarkStatus.missing, MarkStatus.matched]);
    expect(marks[1].scriptWord, '크게');
  });

  test('단어 하나 더함 → extra', () {
    final marks = compareToScript('경제가 크게 성장했습니다', '경제가 아주 크게 성장했습니다');
    expect(statuses(marks), [
      MarkStatus.matched,
      MarkStatus.extra,
      MarkStatus.matched,
      MarkStatus.matched,
    ]);
    expect(marks[1].heardWord, '아주');
  });

  test('띄어쓰기만 다름 → 모두 matched', () {
    final marks = compareToScript('성장 했습니다', '성장했습니다');
    expect(statuses(marks), everyElement(MarkStatus.matched));
    final marks2 = compareToScript('성장했습니다', '성장 했습니다');
    expect(statuses(marks2), everyElement(MarkStatus.matched));
  });

  test('숫자 표기 차이 → matched', () {
    final marks = compareToScript('2026년', '이천이십육년');
    expect(statuses(marks), [MarkStatus.matched]);
  });

  test('인식이 빈 문자열 → 모두 missing (Review Focus 1)', () {
    final marks = compareToScript('경제가 크게 성장했습니다', '');
    expect(statuses(marks), everyElement(MarkStatus.missing));
    expect(marks, hasLength(3));
  });

  test('빈 원고 → 빈 결과', () {
    expect(compareToScript('', '아무 말'), isEmpty);
  });

  test('v1에서 score는 항상 null', () {
    final marks = compareToScript('경제가 성장했습니다', '경제가 생장했습니다');
    expect(marks.every((m) => m.score == null), isTrue);
  });
}
