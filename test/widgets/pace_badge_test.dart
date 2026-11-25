import 'package:announcer_app/analysis/syllable_rate.dart';
import 'package:announcer_app/widgets/studio.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, PaceFeedback f) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: PaceBadge(feedback: f)))));

void main() {
  testWidgets('빠르면 빨라요', (tester) async {
    await pump(tester, PaceFeedback.fast);
    await tester.pumpAndSettle();
    expect(find.text('빨라요'), findsOneWidget);
    expect(find.text('느려요'), findsNothing);
  });

  testWidgets('느리면 느려요', (tester) async {
    await pump(tester, PaceFeedback.slow);
    await tester.pumpAndSettle();
    expect(find.text('느려요'), findsOneWidget);
  });

  testWidgets('비슷하면 아무것도 없다', (tester) async {
    await pump(tester, PaceFeedback.none);
    await tester.pumpAndSettle();
    expect(find.text('빨라요'), findsNothing);
    expect(find.text('느려요'), findsNothing);
  });

  testWidgets('빨라요와 느려요는 색이 다르다', (tester) async {
    Color? colorOf(String text) =>
        (tester.widget<Container>(find.ancestor(of: find.text(text), matching: find.byType(Container)).first)
                .decoration as BoxDecoration?)
            ?.color;
    await pump(tester, PaceFeedback.fast);
    await tester.pumpAndSettle();
    final fast = colorOf('빨라요');
    await pump(tester, PaceFeedback.slow);
    await tester.pumpAndSettle();
    final slow = colorOf('느려요');
    expect(fast, isNotNull);
    expect(fast, isNot(slow));
  });
}
