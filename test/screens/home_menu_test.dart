import 'package:announcer_app/data/models.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late TestStore store;
  setUp(() async => store = await TestStore.open());
  tearDown(() => store.close());

  testWidgets('시작 화면 뒤에 메뉴 네 개가 보인다', (tester) async {
    await store.pumpApp(tester);
    expect(find.text('My Diction'), findsOneWidget);
    for (final label in ['발음연습', '원고관리', '녹음관리', '퍼펙트딕션']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('준비 중'), findsNothing);
    expect(find.textContaining('점수'), findsNothing);
  });

  testWidgets('발음연습: 원고를 고르면 온에어 녹음 화면이 열린다', (tester) async {
    await store.scripts.add(
        Script(title: '9시 뉴스', body: '시청자 여러분, 안녕하십니까.', createdAt: DateTime(2026)));
    await store.pumpApp(tester);
    await tester.tap(find.text('발음연습'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9시 뉴스'));
    await tester.pumpAndSettle();
    expect(find.text('온에어.'), findsOneWidget);
    expect(find.text('ON AIR'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('9시 뉴스'), findsOneWidget);
  });

  testWidgets('발음연습: 폴더 칩으로 원고를 거른다', (tester) async {
    final news = await store.folders.add('뉴스');
    await store.scripts.add(
        Script(title: '뉴스 원고', body: '뉴스입니다', folderId: news, createdAt: DateTime(2026)));
    await store.scripts.add(Script(title: '자유 원고', body: '자유입니다', createdAt: DateTime(2026)));
    await store.pumpApp(tester);
    await tester.tap(find.text('발음연습'));
    await tester.pumpAndSettle();
    expect(find.text('뉴스 원고'), findsOneWidget);
    expect(find.text('자유 원고'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '뉴스'));
    await tester.pumpAndSettle();
    expect(find.text('뉴스 원고'), findsOneWidget);
    expect(find.text('자유 원고'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, '폴더 없음'));
    await tester.pumpAndSettle();
    expect(find.text('뉴스 원고'), findsNothing);
    expect(find.text('자유 원고'), findsOneWidget);
  });

  testWidgets('발음연습: 원고가 없으면 원고관리로 안내한다', (tester) async {
    await store.pumpApp(tester);
    await tester.tap(find.text('발음연습'));
    await tester.pumpAndSettle();
    expect(find.text('연습할 원고가 없어요'), findsOneWidget);
    await tester.tap(find.text('원고관리로 가기'));
    await tester.pumpAndSettle();
    expect(find.text('연습할 원고를 붙여넣어 주세요'), findsOneWidget);
  });

  testWidgets('퍼펙트딕션을 누르면 도전 목록이 열린다', (tester) async {
    await store.pumpApp(tester);
    await tester.tap(find.text('퍼펙트딕션'));
    await tester.pumpAndSettle();
    expect(find.text('잰말놀이'), findsOneWidget);
    expect(find.text('곧 만나요'), findsNothing);
  });
}
