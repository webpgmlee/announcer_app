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

  test('읽은 위치가 속한 줄을 찾는다 (다 읽은 어절은 다음 어절로 넘어감)', () {
    final words = ['안녕하십니까.', '11월', '23일,', '9시'];
    final lines = layoutLines(4, autoPauses(words)); // [0,1) [1,3) [3,4)
    final offsets = syllableOffsets(words); // [0, 6, 9, 13, 15]
    expect(lineForPosition(lines, offsets, 0), 0);
    expect(lineForPosition(lines, offsets, 5), 0);
    expect(lineForPosition(lines, offsets, 6), 1);
    expect(lineForPosition(lines, offsets, 12), 1);
    expect(lineForPosition(lines, offsets, 13), 2);
    expect(lineForPosition(lines, offsets, 15), 2); // 끝까지 읽으면 마지막 줄
    expect(lineForPosition(const [], [0], 0), 0);
  });
}
