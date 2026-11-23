import 'package:announcer_app/app.dart';
import 'package:announcer_app/data/database.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/data/script_repository.dart';
import 'package:announcer_app/data/session_repository.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late ScriptRepository scripts;

  setUp(() async {
    db = await openAppDatabase(inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate);
    final sessions = SessionRepository(db);
    scripts = ScriptRepository(db, sessions);
  });
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        scriptRepositoryProvider.overrideWithValue(scripts),
        sessionRepositoryProvider.overrideWithValue(SessionRepository(db)),
      ],
      child: const AnnouncerApp(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('원고가 0개면 붙여넣기 안내와 버튼이 보인다', (tester) async {
    await pumpApp(tester);
    expect(find.text('연습할 원고를 붙여넣어 주세요'), findsOneWidget);
    expect(find.text('원고 붙여넣기'), findsOneWidget);
  });

  testWidgets('붙여넣고 저장하면 목록에 제목과 음절 수가 나온다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('원고 붙여넣기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('title')), '첫 원고');
    await tester.enterText(find.byKey(const Key('body')), '안녕하세요. 뉴스입니다!');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(find.text('첫 원고'), findsOneWidget);
    expect(find.text('10음절'), findsOneWidget);
    expect(find.text('연습할 원고를 붙여넣어 주세요'), findsNothing);
  });

  testWidgets('빈 본문은 저장 버튼이 꺼져 있다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('원고 붙여넣기'));
    await tester.pumpAndSettle();

    FilledButton save() => tester.widget<FilledButton>(find.byKey(const Key('save')));
    expect(save().onPressed, isNull);
    await tester.enterText(find.byKey(const Key('body')), '   \n  ');
    await tester.pump();
    expect(save().onPressed, isNull);
    await tester.enterText(find.byKey(const Key('body')), '가');
    await tester.pump();
    expect(save().onPressed, isNotNull);
  });

  testWidgets('제목을 비우면 본문 앞 20자를 제목으로 쓴다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('원고 붙여넣기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('body')),
        '오늘 오전 기상청은 이번 주말까지 전국에 맑은 날씨가 이어지겠다고 밝혔습니다.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    final saved = (await scripts.all()).single;
    expect(saved.title, '오늘 오전 기상청은 이번 주말까지 전');
    expect(saved.title.length, 20);
  });

  testWidgets('붙여넣기 버튼은 클립보드 내용을 본문에 넣는다', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, dynamic>{'text': '클립보드 원고입니다'}
          : null,
    );
    await pumpApp(tester);
    await tester.tap(find.text('원고 붙여넣기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paste')));
    await tester.pumpAndSettle();
    expect(find.text('클립보드 원고입니다'), findsOneWidget);
  });

  testWidgets('원고를 밀어서 지우면 확인 후 사라진다', (tester) async {
    await scripts.add(Script(
        title: '지울 원고', body: '본문', createdAt: DateTime(2026, 11, 23)));
    await pumpApp(tester);
    await tester.drag(find.text('지울 원고'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('지울 원고'), findsNothing);
    expect(await scripts.all(), isEmpty);
  });

  testWidgets('저장된 원고가 있으면 바로 목록을 보여준다', (tester) async {
    await scripts.add(Script(
        title: '저장된 원고', body: 'KBS 뉴스', createdAt: DateTime(2026, 11, 23)));
    await pumpApp(tester);
    expect(find.text('저장된 원고'), findsOneWidget);
    expect(find.text('7음절'), findsOneWidget); // 케이비에스뉴스
  });
}
