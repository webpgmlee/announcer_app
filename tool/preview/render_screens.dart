// 화면 미리보기 이미지를 만든다 (실기기 없이 디자인 확인용). 일반 테스트에 섞이지 않게 tool/ 아래에 둔다.
// 실행: flutter test --update-goldens tool/preview/render_screens.dart
// 결과: tool/preview/out/*.png (휴대폰 크기 390×844, 3배 해상도)
import 'dart:io';

import 'package:announcer_app/analysis/pitch.dart';
import 'package:announcer_app/data/default_scripts.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/data/news_library.dart';
import 'package:announcer_app/screens/script_detail_screen.dart';
import 'package:announcer_app/screens/script_manage_screen.dart';
import 'package:announcer_app/theme.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers.dart';

const _flutterFonts =
    'C:/app_workspace/flutter_windows_3.50.1-stable/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final bytes = File(p).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
  }
  await loader.load();
}

void main() {
  late TestStore store;

  setUpAll(() async {
    // 테스트 기본 글꼴(네모 상자) 대신 한글이 보이는 글꼴과 아이콘 글꼴을 쓴다.
    await _loadFont('Roboto', ['C:/Windows/Fonts/malgun.ttf', 'C:/Windows/Fonts/malgunbd.ttf']);
    await _loadFont('MaterialIcons', ['$_flutterFonts/materialicons-regular.otf']);
  });

  setUp(() async {
    store = await TestStore.open();
    await seedDefaultScripts(store.db, store.scripts);
    await seedNewsLibrary(store.db, store.scripts, store.folders);
    // 연습 중 원고 두 개를 만든다.
    final all = await store.scripts.all();
    Future<void> rec(String titlePart, List<DateTime> times) async {
      final s = all.firstWhere((x) => x.title.contains(titlePart));
      for (final t in times) {
        await store.sessions.add(PracticeSession(
          scriptId: s.id!,
          audioPath: 'x_${t.millisecondsSinceEpoch}.wav',
          elapsed: const Duration(seconds: 40),
          syllablesPerMinute: 340,
          pitch: const [PitchPoint(t: Duration.zero, hz: 200)],
          createdAt: t,
        ));
      }
    }

    await rec('기준금리 동결', [DateTime(2026, 11, 24, 21), DateTime(2026, 11, 25, 9)]);
    await rec('가족 영화 흥행', [DateTime(2026, 11, 23, 20)]);
  });
  tearDown(() => store.close());

  Future<void> shoot(WidgetTester tester, Widget screen, String name,
      {Future<void> Function()? before}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: store.overrides,
      child: RepaintBoundary(
        key: const ValueKey('shot'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: screen,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    if (before != null) {
      await before();
      await tester.pumpAndSettle();
    }
    await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/$name.png'));
  }

  testWidgets('1 원고관리 - 연습 중', (tester) async {
    await shoot(tester, const ScriptManageScreen(), '1_manage_practicing');
  });

  testWidgets('2 원고관리 - 경제 분야', (tester) async {
    await shoot(tester, const ScriptManageScreen(), '2_manage_economy', before: () async {
      await tester.tap(find.widgetWithText(ChoiceChip, '경제'));
    });
  });

  testWidgets('3 원고 조회', (tester) async {
    final s = (await store.scripts.all()).firstWhere((x) => x.title.contains('기준금리 동결'));
    await shoot(tester, ScriptDetailScreen(script: s), '3_detail');
  });

  testWidgets('4 검색', (tester) async {
    await shoot(tester, const ScriptManageScreen(), '4_search', before: () async {
      await tester.enterText(find.byType(TextField), '금리');
    });
  });
}
