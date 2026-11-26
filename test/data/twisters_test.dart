import 'package:announcer_app/analysis/read_aloud.dart';
import 'package:announcer_app/data/twisters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('잰말놀이 15개, 단계마다 5개, 아이디는 겹치지 않는다', () {
    expect(twisters, hasLength(15));
    for (final stage in [1, 2, 3]) {
      expect(twisters.where((t) => t.stage == stage), hasLength(5));
    }
    expect(twisters.map((t) => t.id).toSet(), hasLength(15));
  });

  test('간장공장 공장장이 들어 있다', () {
    expect(twisters.any((t) => t.body.contains('간장 공장 공장장')), isTrue);
  });

  test('모든 문장은 마침표로 끝나고 소리로 읽을 수 있다', () {
    for (final t in twisters) {
      expect(t.body.trim(), endsWith('.'), reason: t.title);
      expect(RegExp('[A-Za-z]').hasMatch(readAloud(t.body)), isFalse, reason: t.title);
    }
  });

  test('단계별 목표 속도', () {
    expect(stagePace(1), 300);
    expect(stagePace(2), 350);
    expect(stagePace(3), 400);
  });

  test('1단계는 늘 열려 있고, 다음 단계는 앞 단계 별 5개부터', () {
    final s1 = twisters.where((t) => t.stage == 1).map((t) => t.id).toList();
    expect(stageUnlocked(1, const {}), isTrue);
    expect(stageUnlocked(2, const {}), isFalse);
    final four = {s1[0]: 3, s1[1]: 1};
    expect(starsInStage(1, four), 4);
    expect(stageUnlocked(2, four), isFalse);
    final five = {s1[0]: 3, s1[1]: 2};
    expect(stageUnlocked(2, five), isTrue);
    expect(stageUnlocked(3, five), isFalse);
  });
}
