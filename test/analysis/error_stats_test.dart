import 'package:announcer_app/analysis/compare.dart';
import 'package:announcer_app/analysis/error_stats.dart';
import 'package:flutter_test/flutter_test.dart';

WordMark m(String w, MarkStatus s) => WordMark(scriptWord: w, status: s);
const extra = WordMark(scriptWord: '', heardWord: '아주', status: MarkStatus.extra);

void main() {
  test('세 녹음 중 두 번 틀린 어절은 자주 틀림', () {
    final stats = errorStats([
      [m('a', MarkStatus.matched), m('b', MarkStatus.misheard), m('c', MarkStatus.matched)],
      [m('a', MarkStatus.matched), m('b', MarkStatus.missing), m('c', MarkStatus.misheard)],
      [m('a', MarkStatus.matched), m('b', MarkStatus.matched), m('c', MarkStatus.matched)],
    ]);
    expect(stats.recognized, 3);
    expect(stats.wrong[1], 2);
    expect(stats.wrong[2], 1);
    expect(stats.wrong.containsKey(0), isFalse);
    expect(stats.isFrequent(1), isTrue);
    expect(stats.isFrequent(2), isFalse);
    expect(stats.isFrequent(0), isFalse);
  });

  test('덧붙인 말(extra)이 끼어 있어도 어절 번호가 밀리지 않는다', () {
    final stats = errorStats([
      [m('a', MarkStatus.matched), extra, m('b', MarkStatus.misheard)],
      [extra, m('a', MarkStatus.matched), m('b', MarkStatus.missing)],
    ]);
    expect(stats.wrong, {1: 2});
  });

  test('인식이 안 끝난 녹음(null)은 세지 않는다', () {
    final stats = errorStats([null, [m('a', MarkStatus.misheard)]]);
    expect(stats.recognized, 1);
    expect(stats.wrong, {0: 1});
  });

  test('기록이 없으면 비어 있다', () {
    final stats = errorStats(const []);
    expect(stats.recognized, 0);
    expect(stats.wrong, isEmpty);
    expect(frequentErrorMin, 2);
  });
}
