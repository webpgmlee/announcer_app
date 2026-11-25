import 'package:announcer_app/screens/splash_screen.dart';
import 'package:announcer_app/theme.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: const SplashScreen(next: Scaffold(body: Text('메인 화면'))),
    ));

double opacityOfTitle(WidgetTester tester) => tester
    .widget<FadeTransition>(find
        .ancestor(of: find.text('My Diction'), matching: find.byType(FadeTransition))
        .first)
    .opacity
    .value;

void main() {
  testWidgets('앱 이름과 아이콘이 페이드인된다', (tester) async {
    await pump(tester);
    expect(find.text('My Diction'), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-icon')), findsOneWidget);
    expect(opacityOfTitle(tester), lessThan(0.1));
    await tester.pump(const Duration(milliseconds: 900));
    expect(opacityOfTitle(tester), closeTo(1, 0.01));
    expect(find.text('메인 화면'), findsNothing);
  });

  testWidgets('잠시 머문 뒤 페이드아웃되고 메인 화면으로 넘어간다', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(opacityOfTitle(tester), lessThan(0.6)); // 사라지는 중
    await tester.pumpAndSettle();
    expect(find.text('My Diction'), findsNothing);
    expect(find.text('메인 화면'), findsOneWidget);
  });

  testWidgets('화면을 누르면 기다리지 않고 바로 넘어간다', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(SplashScreen));
    await tester.pumpAndSettle();
    expect(find.text('메인 화면'), findsOneWidget);
  });

  test('전체 길이는 약 2초', () {
    expect(splashDuration, const Duration(milliseconds: 2200));
  });
}
