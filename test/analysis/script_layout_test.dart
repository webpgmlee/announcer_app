import 'package:announcer_app/analysis/script_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('어절은 공백으로 나눈다', () {
    expect(scriptWords(' 시청자  여러분,\n안녕하십니까. '), ['시청자', '여러분,', '안녕하십니까.']);
    expect(scriptWords('   '), isEmpty);
  });

  test('쉼표 뒤는 /, 마침표·물음표·느낌표 뒤는 //', () {
    expect(autoPauses(['안녕하십니까.', '11월', '23일,', '9시']),
        {0: Pause.breath, 2: Pause.pause});
    expect(autoPauses(['정말?', '네!', '그래서', '…']), {0: Pause.breath, 1: Pause.breath});
    expect(autoPauses(['인용했다."', '그는,"']), {0: Pause.breath, 1: Pause.pause});
  });

  test('누르면 없음 → / → // → 없음', () {
    expect(cyclePause(Pause.none), Pause.pause);
    expect(cyclePause(Pause.pause), Pause.breath);
    expect(cyclePause(Pause.breath), Pause.none);
  });

  test('표시 뒤에서 줄을 나눈다', () {
    final lines = layoutLines(4, {0: Pause.breath, 2: Pause.pause});
    expect(lines.map((l) => (l.start, l.end, l.endPause)), [
      (0, 1, Pause.breath),
      (1, 3, Pause.pause),
      (3, 4, Pause.none),
    ]);
  });

  test('표시가 없으면 한 줄, 빈 원고는 줄 없음', () {
    expect(layoutLines(3, {}).map((l) => (l.start, l.end)), [(0, 3)]);
    expect(layoutLines(0, {}), isEmpty);
  });

  test('none 값이나 범위 밖 표시는 무시한다', () {
    final lines = layoutLines(3, {0: Pause.none, 7: Pause.pause, 2: Pause.breath});
    expect(lines.map((l) => (l.start, l.end)), [(0, 3)]);
  });

  test('어절별 읽는 소리 글자 위치', () {
    expect(syllableOffsets(['KBS', '뉴스']), [0, 5, 7]);
    expect(syllableOffsets(['2026년,', '안녕']), [0, 6, 8]);
    expect(syllableOffsets([]), [0]);
  });
}
