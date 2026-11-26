import 'package:announcer_app/analysis/pitch.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/widgets/script_browser.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late TestStore store;
  setUp(() async => store = await TestStore.open());
  tearDown(() => store.close());

  Future<void> openManage(WidgetTester tester) async {
    await store.pumpApp(tester);
    await tester.tap(find.text('원고관리'));
    await tester.pumpAndSettle();
  }

  Future<int> addScript(String title, {int? folderId}) => store.scripts.add(Script(
      title: title, body: '안녕하십니까. 뉴스입니다.', folderId: folderId, createdAt: DateTime(2026)));

  Future<void> openMenu(WidgetTester tester, String title, String item) async {
    await tester.tap(find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(ScriptCard)),
        matching: find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  Future<void> record(int scriptId) => store.sessions.add(PracticeSession(
      scriptId: scriptId,
      audioPath: 'x.wav',
      elapsed: const Duration(seconds: 5),
      syllablesPerMinute: 300,
      pitch: const [PitchPoint(t: Duration.zero, hz: 200)],
      createdAt: DateTime(2026, 11, 25)));

  testWidgets('연습 완료: 메뉴에서 누르면 연습 중에서 빠져 분야 목록으로 돌아간다', (tester) async {
    final id = await addScript('날씨');
    await record(id);
    await openManage(tester);
    expect(find.widgetWithText(ChoiceChip, '연습 중 1'), findsOneWidget);
    await openMenu(tester, '날씨', '연습 완료');
    expect(find.widgetWithText(ChoiceChip, '연습 중 0'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '전체'));
    await tester.pumpAndSettle();
    expect(find.text('날씨'), findsOneWidget);
    expect((await store.scripts.all()).single.completedAt, isNotNull);
  });

  testWidgets('연습 중이 아닌 원고의 메뉴에는 연습 완료가 없다', (tester) async {
    await addScript('날씨');
    await openManage(tester);
    await tester.tap(find.descendant(
        of: find.ancestor(of: find.text('날씨'), matching: find.byType(ScriptCard)),
        matching: find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
    expect(find.text('연습 완료'), findsNothing);
  });

  testWidgets('조회 화면에서도 연습 완료를 누를 수 있다', (tester) async {
    final id = await addScript('날씨');
    await record(id);
    await openManage(tester);
    await tester.tap(find.text('날씨'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('연습 완료'));
    await tester.pumpAndSettle();
    expect((await store.scripts.all()).single.completedAt, isNotNull);
    expect(find.text('연습 완료'), findsNothing); // 완료한 뒤에는 버튼이 사라진다
  });

  testWidgets('원고가 없으면 붙여넣기 안내', (tester) async {
    await openManage(tester);
    expect(find.text('연습할 원고를 붙여넣어 주세요'), findsOneWidget);
    expect(find.text('원고 붙여넣기'), findsOneWidget);
  });

  testWidgets('추가: 폴더를 골라 붙여넣고 저장하면 목록에 나온다', (tester) async {
    await store.folders.add('뉴스');
    await openManage(tester);
    await tester.tap(find.text('원고 붙여넣기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('title')), '첫 원고');
    await tester.enterText(find.byKey(const Key('body')), '안녕하세요. 뉴스입니다!');
    await tester.tap(find.byKey(const Key('folder-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('뉴스').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('첫 원고'), findsOneWidget);
    final saved = (await store.scripts.all()).single;
    expect(saved.folderId, isNotNull);
  });

  testWidgets('빈 본문은 저장할 수 없다', (tester) async {
    await openManage(tester);
    await tester.tap(find.text('원고 붙여넣기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('body')), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('save'))).onPressed, isNull);
  });

  testWidgets('붙여넣기 버튼은 클립보드 내용을 넣는다', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? <String, dynamic>{'text': '클립보드 원고입니다'} : null,
    );
    await openManage(tester);
    await tester.tap(find.text('원고 붙여넣기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paste')));
    await tester.pumpAndSettle();
    expect(find.text('클립보드 원고입니다'), findsOneWidget);
  });

  testWidgets('조회: 본문, 음절 수, 녹음 횟수가 보인다', (tester) async {
    final id = await addScript('날씨');
    await store.sessions.add(PracticeSession(
        scriptId: id,
        audioPath: 'x.wav',
        elapsed: const Duration(seconds: 5),
        syllablesPerMinute: 300,
        pitch: const [PitchPoint(t: Duration.zero, hz: 200)],
        createdAt: DateTime(2026)));
    await openManage(tester);
    await tester.tap(find.text('날씨'));
    await tester.pumpAndSettle();
    expect(find.text(keepWords('안녕하십니까. 뉴스입니다.')), findsOneWidget);
    expect(find.text('11음절'), findsOneWidget);
    expect(find.text('녹음 1번'), findsOneWidget);
    expect(find.text('이 원고로 연습'), findsOneWidget);
  });

  testWidgets('복제하면 (복사본)이 생긴다', (tester) async {
    await addScript('날씨');
    await openManage(tester);
    await openMenu(tester, '날씨', '복제');
    expect(find.text('날씨 (복사본)'), findsOneWidget);
    expect(await store.scripts.all(), hasLength(2));
  });

  testWidgets('삭제는 확인을 받고 지운다', (tester) async {
    await addScript('날씨');
    await openManage(tester);
    await openMenu(tester, '날씨', '삭제');
    expect(find.text('원고를 지울까요?'), findsOneWidget);
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(find.text('날씨'), findsNothing);
    expect(await store.scripts.all(), isEmpty);
  });

  testWidgets('폴더 이동', (tester) async {
    final f = await store.folders.add('뉴스');
    await addScript('날씨');
    await openManage(tester);
    await openMenu(tester, '날씨', '폴더 이동');
    await tester.tap(find.text('뉴스').last);
    await tester.pumpAndSettle();
    expect((await store.scripts.all()).single.folderId, f);
  });

  testWidgets('폴더 관리: 추가, 이름 수정, 삭제(원고는 폴더 없음으로)', (tester) async {
    await openManage(tester);
    await tester.tap(find.byTooltip('폴더 관리'));
    await tester.pumpAndSettle();
    expect(find.text('아직 폴더가 없어요'), findsOneWidget);

    await tester.tap(find.text('폴더 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '뉴스');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('뉴스'), findsOneWidget);

    // 같은 이름은 안내만 하고 만들지 않는다
    await tester.tap(find.text('폴더 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '뉴스');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('같은 이름의 폴더가 있어요'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(await store.folders.all(), hasLength(1));

    final id = (await store.folders.all()).single.id!;
    await store.scripts.add(Script(
        title: '안의 원고', body: '본문입니다', folderId: id, createdAt: DateTime(2026)));

    await tester.tap(find.byTooltip('이름 바꾸기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '아침 뉴스');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('아침 뉴스'), findsOneWidget);

    await tester.tap(find.byTooltip('폴더 지우기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('폴더 없음으로 옮겨져요'), findsOneWidget);
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(await store.folders.all(), isEmpty);
    expect((await store.scripts.all()).single.folderId, isNull);
  });
}
