import 'package:announcer_app/analysis/karaoke.dart';
import 'package:announcer_app/analysis/script_layout.dart';
import 'package:flutter_test/flutter_test.dart';

Duration secs(double s) => Duration(microseconds: (s * 1e6).round());

void main() {
  final words = scriptWords('안녕하십니까. 9시 뉴스를, 시작하겠습니다.');
  // 음절: 안녕하십니까(6) 구시(2) 뉴스를(3) 시작하겠습니다(7) = 18
  final pauses = autoPauses(words); // {0: breath, 2: pause, 3: breath}
  const per = 60 / 350; // 350음절/분에서 한 음절 초

  test('기본값과 속도 범위', () {
    expect(defaultPace, 350);
    expect(clampPace(123), 200);
    expect(clampPace(347), 350);
    expect(clampPace(999), 500);
    expect(clampPace(352.4), 350);
    expect(clampPace(double.nan), defaultPace);
  });

  test('문장은 // 에서만 나눈다', () {
    expect(sentencesOf(words.length, pauses).map((s) => (s.start, s.end)), [(0, 1), (1, 4)]);
    expect(sentencesOf(0, const {}), isEmpty);
  });

  test('전체 시간 = 음절 시간 + 쉼(0.3초)·숨(0.6초)', () {
    final t = KaraokeTimeline(words, pauses, 350);
    final expected = 18 * per + 0.6 + 0.3 + 0.6;
    expect(t.total.inMicroseconds / 1e6, closeTo(expected, 0.001));
  });

  test('어절 중간이면 그 어절을 반쯤 채운다', () {
    final f = KaraokeTimeline(words, pauses, 350).at(secs(3 * per));
    expect(f.word, 0);
    expect(f.wordFill, closeTo(0.5, 0.001));
    expect(f.sentence, 0);
    expect(f.position, 3);
    expect(f.done, isFalse);
  });

  test('숨 쉬는 동안에는 앞 어절이 다 채워져 있고 다음 어절은 시작 전', () {
    final f = KaraokeTimeline(words, pauses, 350).at(secs(6 * per + 0.3));
    expect(f.word, 0);
    expect(f.wordFill, 1);
    expect(f.position, 6);
  });

  test('숨이 끝나면 다음 문장으로 넘어간다', () {
    final f = KaraokeTimeline(words, pauses, 350).at(secs(6 * per + 0.6 + 0.001));
    expect(f.word, 1);
    expect(f.sentence, 1);
  });

  test('진행률과 남은 시간', () {
    final t = KaraokeTimeline(words, pauses, 350);
    final f = t.at(secs(9 * per + 0.6)); // 안녕하십니까·구시·뉴스를의 첫 음절
    expect(f.position, 9);
    expect(f.progress, closeTo(9 / 18, 0.001));
    expect(f.remaining, t.total - secs(9 * per + 0.6));
  });

  test('시작 전(음수)은 처음, 끝난 뒤는 done', () {
    final t = KaraokeTimeline(words, pauses, 350);
    final before = t.at(const Duration(seconds: -2));
    expect(before.word, 0);
    expect(before.wordFill, 0);
    expect(before.position, 0);
    expect(before.remaining, t.total);
    final after = t.at(t.total + const Duration(milliseconds: 1));
    expect(after.done, isTrue);
    expect(after.progress, 1);
    expect(after.remaining, Duration.zero);
  });

  test('속도가 두 배면 음절 시간이 절반', () {
    final slow = KaraokeTimeline(words, const {}, 200).total;
    final fast = KaraokeTimeline(words, const {}, 400).total;
    expect(fast.inMicroseconds * 2, closeTo(slow.inMicroseconds, 2));
  });

  test('빈 원고·기호만 있는 원고는 시간 0, 바로 done (Review Focus 1)', () {
    expect(KaraokeTimeline(const [], const {}, 350).at(Duration.zero).done, isTrue);
    final symbols = KaraokeTimeline(const ['…', '—'], const {}, 350);
    expect(symbols.total, Duration.zero);
    expect(symbols.at(Duration.zero).done, isTrue);
  });
}
