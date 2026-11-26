import 'package:announcer_app/analysis/pitch.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/widgets/script_browser.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late TestStore store;
  setUp(() async => store = await TestStore.open());
  tearDown(() => store.close());

  Script? opened;

  Future<void> pump(WidgetTester tester) async {
    opened = null;
    await tester.pumpWidget(ProviderScope(
      overrides: store.overrides,
      child: MaterialApp(
          home: Scaffold(body: ScriptBrowser(onOpen: (s) => opened = s))),
    ));
    await tester.pumpAndSettle();
  }

  Future<int> add(String title, String body, {int? folderId, int? level}) =>
      store.scripts.add(Script(
          title: title,
          body: body,
          folderId: folderId,
          difficulty: level,
          createdAt: DateTime(2026)));

  Future<void> record(int id, DateTime at) => store.sessions.add(PracticeSession(
        scriptId: id,
        audioPath: 'x_${at.millisecondsSinceEpoch}.wav',
        elapsed: const Duration(seconds: 5),
        syllablesPerMinute: 300,
        pitch: const [PitchPoint(t: Duration.zero, hz: 200)],
        createdAt: at,
      ));

  Finder card(String title) => find.ancestor(of: find.text(title), matching: find.byType(ScriptCard));

  testWidgets('카드: 난이도 배지, 앞말 뺀 제목, 첫 줄 미리보기, 음절·예상 시간·녹음', (tester) async {
    await add('초급 · 추석 앞둔 전통시장', '추석을 앞두고 시장이 붐빕니다.\n둘째 줄입니다.', level: 1);
    await pump(tester);
    expect(find.text('추석 앞둔 전통시장'), findsOneWidget);
    expect(find.text('초급 · 추석 앞둔 전통시장'), findsNothing);
    expect(find.descendant(of: card('추석 앞둔 전통시장'), matching: find.text('초급')), findsOneWidget);
    expect(find.text('추석을 앞두고 시장이 붐빕니다.'), findsOneWidget);
    expect(find.textContaining('둘째 줄'), findsNothing);
    // 추석을앞두고시장이붐빕니다(13) 둘째줄입니다(6) = 19음절, 350음절/분이면 약 3초
    expect(find.text('19음절 · 약 3초 · 녹음 없음'), findsOneWidget);
  });

  testWidgets('누르면 그 원고를 연다', (tester) async {
    await add('가', '본문입니다.');
    await pump(tester);
    await tester.tap(find.text('가'));
    expect(opened?.title, '가');
  });

  testWidgets('연습 중인 원고는 분야 목록에서 빠지고 연습 중 버튼에서만 보인다', (tester) async {
    final f = await store.folders.add('경제');
    final a = await add('연습한 원고', '본문입니다.', folderId: f);
    await add('새 원고', '본문입니다.', folderId: f);
    await record(a, DateTime(2026, 11, 25, 9, 30));
    await pump(tester);

    // 연습 중이 있으면 처음에 연습 중을 보여준다
    expect(find.widgetWithText(ChoiceChip, '연습 중 1'), findsOneWidget);
    expect(find.text('연습한 원고'), findsOneWidget);
    expect(find.text('새 원고'), findsNothing);
    expect(find.textContaining('마지막 연습 11.25'), findsOneWidget);
    expect(find.textContaining('녹음 1번'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '경제'));
    await tester.pumpAndSettle();
    expect(find.text('새 원고'), findsOneWidget);
    expect(find.text('연습한 원고'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '전체'));
    await tester.pumpAndSettle();
    expect(find.text('연습한 원고'), findsNothing);
  });

  testWidgets('연습 중이 없으면 처음에 전체를 보여주고, 연습 중 버튼은 안내를 보인다', (tester) async {
    await add('새 원고', '본문입니다.');
    await pump(tester);
    expect(find.text('새 원고'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '연습 중 0'));
    await tester.pumpAndSettle();
    expect(find.text('아직 연습 중인 원고가 없어요'), findsOneWidget);
  });

  testWidgets('분야 안에서는 초급·중급·고급 순서로 묶어 보여준다', (tester) async {
    final f = await store.folders.add('경제');
    await add('고급 원고', '본문.', folderId: f, level: 3);
    await add('초급 원고', '본문.', folderId: f, level: 1);
    await add('중급 원고', '본문.', folderId: f, level: 2);
    await pump(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '경제'));
    await tester.pumpAndSettle();
    final y = {
      for (final t in ['초급 원고', '중급 원고', '고급 원고']) t: tester.getTopLeft(find.text(t)).dy,
    };
    expect(y['초급 원고']!, lessThan(y['중급 원고']!));
    expect(y['중급 원고']!, lessThan(y['고급 원고']!));
    expect(find.byKey(const ValueKey('section-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('section-3')), findsOneWidget);
  });

  testWidgets('검색: 제목·본문에서 찾고, 연습 중인 원고도 함께 찾는다', (tester) async {
    final a = await add('금리 소식', '중앙은행이 기준금리를 동결했습니다.');
    await add('날씨 소식', '내일은 맑겠습니다.');
    await record(a, DateTime(2026, 11, 25));
    await pump(tester);
    await tester.enterText(find.byType(TextField), '맑겠');
    await tester.pumpAndSettle();
    expect(find.text('날씨 소식'), findsOneWidget);
    expect(find.text('금리 소식'), findsNothing);
    await tester.enterText(find.byType(TextField), '기준금리');
    await tester.pumpAndSettle();
    expect(find.text('금리 소식'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '없는 말');
    await tester.pumpAndSettle();
    expect(find.text('찾는 원고가 없어요'), findsOneWidget);
  });

  testWidgets('특정 폴더를 볼 때는 카드에 폴더 이름을 다시 쓰지 않는다', (tester) async {
    final f = await store.folders.add('경제');
    await add('금리 소식', '본문입니다.', folderId: f);
    await pump(tester);
    // 전체에서는 어느 폴더인지 보인다 (칩의 '경제'와 카드의 '경제')
    expect(find.text('경제'), findsNWidgets(2));
    await tester.tap(find.widgetWithText(ChoiceChip, '경제'));
    await tester.pumpAndSettle();
    expect(find.text('경제'), findsOneWidget); // 칩만
  });

  test('낱말 중간에서 줄이 바뀌지 않게 글자 사이를 붙인다', () {
    final kept = keepWords('예상했다는 반응');
    expect(kept.replaceAll('⁠', ''), '예상했다는 반응');
    expect(kept, '예⁠상⁠했⁠다⁠는 반⁠응');
    expect(keepWords('첫 줄\n둘째 줄'), '첫 줄\n둘⁠째 줄');
  });
}
