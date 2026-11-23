import 'package:announcer_app/analysis/compare.dart';
import 'package:announcer_app/widgets/marked_script.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const marks = [
  WordMark(scriptWord: '경제가', status: MarkStatus.matched),
  WordMark(scriptWord: '성장했습니다', heardWord: '생장했습니다', status: MarkStatus.misheard),
  WordMark(scriptWord: '크게', status: MarkStatus.missing),
  WordMark(scriptWord: '', heardWord: '아주', status: MarkStatus.extra),
];

Future<void> pump(WidgetTester tester, List<WordMark> marks) =>
    tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: MarkedScript(marks: marks)))));

Color? colorOf(WidgetTester tester, int i) {
  final box = tester.widget<Container>(find.descendant(
      of: find.byKey(ValueKey('mark-$i')), matching: find.byType(Container)).first);
  return (box.decoration as BoxDecoration?)?.color;
}

void main() {
  testWidgets('misheard, missing, extra가 서로 다른 색', (tester) async {
    await pump(tester, marks);
    final misheard = colorOf(tester, 1);
    final missing = colorOf(tester, 2);
    final extra = colorOf(tester, 3);
    expect([misheard, missing, extra], everyElement(isNotNull));
    expect({misheard, missing, extra}, hasLength(3));
    expect(colorOf(tester, 0), isNot(anyOf(misheard, missing, extra)));
  });

  testWidgets('원고 어절과 덧붙인 말이 보인다', (tester) async {
    await pump(tester, marks);
    expect(find.text('경제가'), findsOneWidget);
    expect(find.text('성장했습니다'), findsOneWidget);
    expect(find.text('크게'), findsOneWidget);
    expect(find.text('아주'), findsOneWidget);
  });

  testWidgets('misheard를 누르면 "이렇게 들렸어요: …"', (tester) async {
    await pump(tester, marks);
    expect(find.textContaining('이렇게 들렸어요'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mark-1')));
    await tester.pump();
    expect(find.text('이렇게 들렸어요: 생장했습니다'), findsOneWidget);
  });

  testWidgets('missing과 extra를 눌러도 설명이 나온다', (tester) async {
    await pump(tester, marks);
    await tester.tap(find.byKey(const ValueKey('mark-2')));
    await tester.pump();
    expect(find.text('이 부분이 들리지 않았어요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mark-3')));
    await tester.pump();
    expect(find.text('원고에 없는 말이 들렸어요: 아주'), findsOneWidget);
  });

  testWidgets('색 설명이 있다', (tester) async {
    await pump(tester, marks);
    expect(find.text('다르게 들림'), findsOneWidget);
    expect(find.text('빠뜨림'), findsOneWidget);
    expect(find.text('덧붙임'), findsOneWidget);
  });

  testWidgets('단어별 점수가 있으면 함께 표시한다 (B 기능 자리)', (tester) async {
    await pump(tester, const [
      WordMark(scriptWord: '경제가', status: MarkStatus.matched, score: 87.4),
    ]);
    expect(find.text('87'), findsOneWidget);
  });
}
