import 'package:announcer_app/analysis/compare.dart';
import 'package:announcer_app/analysis/error_stats.dart';
import 'package:announcer_app/analysis/script_layout.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/theme.dart';
import 'package:announcer_app/widgets/memo_sheet.dart';
import 'package:announcer_app/widgets/prompter.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final words = scriptWords('안녕하십니까. 11월 23일, 9시 뉴스를 시작하겠습니다. 먼저 오늘의 주요 소식입니다.');
final pauses = autoPauses(words);

WordErrorStats stats(int recognized, Map<int, int> wrong) =>
    WordErrorStats(recognized: recognized, wrong: wrong);

Memo memo(int i, String text, [MemoKind kind = MemoKind.pronunciation]) =>
    Memo(scriptId: 1, wordIndex: i, kind: kind, text: text, createdAt: DateTime(2026));

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(MaterialApp(
    theme: buildTheme(), home: Scaffold(body: SizedBox(width: 380, child: child))));

void main() {
  testWidgets('쉼 / 와 숨 // 표시를 그린다', (tester) async {
    await pump(tester, Prompter(words: words, pauses: pauses, memos: const {}, stats: stats(0, {})));
    expect(find.text('/'), findsNWidgets(1)); // 23일,
    expect(find.text('//'), findsNWidgets(3)); // 안녕하십니까. 시작하겠습니다. 소식입니다.
    expect(find.text('시작하겠습니다.'), findsOneWidget);
  });

  testWidgets('어절 사이를 누르면 그 자리 표시를 바꾸라고 알린다', (tester) async {
    int? tapped;
    await pump(
        tester,
        Prompter(
            words: words,
            pauses: pauses,
            memos: const {},
            stats: stats(0, {}),
            editable: true,
            onTapGap: (i) => tapped = i));
    await tester.tap(find.byKey(const ValueKey('gap-3')));
    expect(tapped, 3);
    await tester.tap(find.byKey(const ValueKey('gap-0')));
    expect(tapped, 0);
  });

  testWidgets('녹음 중(편집 끔)에는 어절 사이를 눌러도 아무 일 없다', (tester) async {
    int? tapped;
    await pump(
        tester,
        Prompter(
            words: words,
            pauses: pauses,
            memos: const {},
            stats: stats(0, {}),
            editable: false,
            onTapGap: (i) => tapped = i));
    await tester.tap(find.byKey(const ValueKey('gap-0')), warnIfMissed: false);
    expect(tapped, isNull);
  });

  testWidgets('어절을 길게 누르면 메모하라고 알린다', (tester) async {
    int? pressed;
    await pump(
        tester,
        Prompter(
            words: words,
            pauses: pauses,
            memos: const {},
            stats: stats(0, {}),
            editable: true,
            onLongPressWord: (i) => pressed = i));
    await tester.longPress(find.text('시작하겠습니다.'));
    expect(pressed, 5);
  });

  testWidgets('메모는 어절 아래 말풍선, 자주 틀린 어절은 횟수 표시', (tester) async {
    await pump(
        tester,
        Prompter(
          words: words,
          pauses: pauses,
          memos: {5: memo(5, "받침 'ㅆ' 또렷하게")},
          stats: stats(3, {5: 3, 2: 1}),
        ));
    expect(find.text("받침 'ㅆ' 또렷하게"), findsOneWidget);
    expect(find.byKey(const ValueKey('frequent-5')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byKey(const ValueKey('frequent-2')), findsNothing); // 한 번은 자주 아님
  });

  testWidgets('강조 메모는 강조 표시가 된다', (tester) async {
    await pump(
        tester,
        Prompter(
          words: words,
          pauses: pauses,
          memos: {4: memo(4, '힘주어', MemoKind.emphasis)},
          stats: stats(0, {}),
        ));
    expect(find.byKey(const ValueKey('emphasis-4')), findsOneWidget);
  });

  testWidgets('지금 문장의 줄들이 크게, 앞 문장은 지나감, 뒤 문장은 다음', (tester) async {
    // 문장: [0,1) [1,6) [6,10) · 줄: [0,1) [1,3) [3,6) [6,10)
    await pump(
        tester,
        Prompter(
            words: words, pauses: pauses, memos: const {}, stats: stats(0, {}), currentSentence: 1));
    expect(find.byKey(const ValueKey('line-0-past')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-1-current')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-2-current')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-3-next')), findsOneWidget);
  });

  testWidgets('진행 중에는 지금 어절까지 글자를 채운다 (노래방)', (tester) async {
    await pump(
        tester,
        Prompter(
          words: words,
          pauses: pauses,
          memos: const {},
          stats: stats(0, {}),
          currentSentence: 1,
          karaoke: true,
          activeWord: 5,
          wordFill: 0.5,
        ));
    final partial = tester.widget<Text>(find.byKey(const ValueKey('fill-5')));
    final spans = (partial.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.map((s) => s.text), ['시작하겠', '습니다.']);
    expect(spans[0].style!.color, filledColor);
    expect(spans[1].style!.color, unfilledColor);
    final done = tester.widget<Text>(find.text('뉴스를'));
    expect(done.style!.color, filledColor);
    expect(find.byKey(const ValueKey('fill-6')), findsNothing);
  });

  testWidgets('한 줄의 어절들은 옆으로 이어진다 (표시 자리가 줄 전체로 늘지 않음)', (tester) async {
    await pump(tester, Prompter(words: words, pauses: pauses, memos: const {}, stats: stats(0, {})));
    final a = tester.getRect(find.byKey(const ValueKey('word-1')));
    final b = tester.getRect(find.byKey(const ValueKey('word-2')));
    expect(b.top, a.top);
    expect(b.left, greaterThan(a.right));
    expect(tester.getRect(find.byKey(const ValueKey('gap-3'))).width, lessThan(40));
  });

  testWidgets('문장부호 없는 긴 원고도 화면 폭을 넘지 않는다 (Review Focus 3)', (tester) async {
    final long = scriptWords(List.filled(40, '경제가 크게 성장했습니다').join(' '));
    await pump(tester,
        Prompter(words: long, pauses: autoPauses(long), memos: const {}, stats: stats(0, {})));
    expect(tester.takeException(), isNull);
  });

  testWidgets('메모 창: 종류를 고르고 글을 써서 저장하면 결과를 돌려준다', (tester) async {
    MemoEdit? result;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showMemoSheet(context,
                word: '시작하겠습니다.', stats: stats(3, {5: 3}), wordIndex: 5),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('길게 눌러 메모'), findsOneWidget);
    expect(find.text('시작하겠습니다'), findsOneWidget);
    expect(find.text('녹음 3번 중 3번 틀림'), findsOneWidget);
    for (final label in ['발음', '속도', '억양', '강조']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('억양'));
    await tester.enterText(find.byType(TextField), '끝을 내려서');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(result!.kind, MemoKind.intonation);
    expect(result!.text, '끝을 내려서');
  });

  testWidgets('메모 창: 기존 메모를 불러오고, 녹음 기록이 없으면 틀림 줄을 숨긴다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showMemoSheet(context,
                word: '먼저',
                wordIndex: 6,
                stats: stats(0, {}),
                memo: memo(6, '천천히', MemoKind.speed)),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('천천히'), findsOneWidget);
    expect(find.textContaining('틀림'), findsNothing);
  });

  test('비교 결과 상수가 바뀌지 않았다', () => expect(MarkStatus.values, hasLength(4)));
}
