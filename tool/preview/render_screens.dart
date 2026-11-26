// 화면 미리보기 이미지를 만든다 (실기기 없이 디자인 확인용). 일반 테스트에 섞이지 않게 tool/ 아래에 둔다.
// 실행: flutter test --update-goldens tool/preview/render_screens.dart
// 결과: tool/preview/out/*.png (휴대폰 크기 390×844, 3배 해상도)
import 'dart:io';

import 'package:announcer_app/analysis/compare.dart';
import 'package:announcer_app/analysis/diction_score.dart';
import 'package:announcer_app/analysis/pitch.dart';
import 'package:announcer_app/data/challenge_repository.dart';
import 'package:announcer_app/data/default_scripts.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/data/news_library.dart';
import 'package:announcer_app/data/twisters.dart';
import 'package:announcer_app/screens/challenge_result_view.dart';
import 'package:announcer_app/screens/challenge_screen.dart';
import 'package:announcer_app/screens/folder_manage_screen.dart';
import 'package:announcer_app/screens/perfect_diction_screen.dart';
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

  DictionScore score(int total, {double acc = 92, double speed = 88, bool perfect = false}) =>
      DictionScore(
        total: total,
        accuracy: acc,
        speed: speed,
        measuredPace: 312,
        stars: starsFor(total),
        perfect: perfect,
      );

  testWidgets('5 퍼펙트딕션 도전 목록', (tester) async {
    final s1 = twisters.where((t) => t.stage == 1).toList();
    await store.challenges.add(twisterKey(s1[0].id), score(96));
    await store.challenges.add(twisterKey(s1[1].id), score(88));
    await store.challenges.add(twisterKey(s1[2].id), score(74));
    await shoot(tester, const PerfectDictionScreen(), '5_perfect_list');
  });

  testWidgets('6 퍼펙트딕션 도전 화면', (tester) async {
    final t = twisters.first;
    await shoot(
        tester,
        ChallengeScreen(
            challengeKey: twisterKey(t.id), title: t.title, body: t.body, pace: stagePace(1)),
        '6_challenge');
  });

  testWidgets('7 퍼펙트딕션 결과', (tester) async {
    await shoot(
        tester,
        Scaffold(
          appBar: AppBar(title: const Text('간장공장 공장장')),
          body: ChallengeResultView(
            score: score(88),
            targetPace: 300,
            newBest: true,
            marks: const [
              WordMark(scriptWord: '간장', status: MarkStatus.matched),
              WordMark(scriptWord: '공장', status: MarkStatus.matched),
              WordMark(scriptWord: '공장장은', heardWord: '공정장은', status: MarkStatus.misheard),
              WordMark(scriptWord: '강', status: MarkStatus.matched),
              WordMark(scriptWord: '공장장이고,', status: MarkStatus.matched),
            ],
            onRetry: () {},
            onExit: () {},
          ),
        ),
        '7_result');
  });

  testWidgets('8 폴더 관리 (기본 폴더 잠금)', (tester) async {
    await store.folders.add('내 연습 원고');
    await shoot(tester, const FolderManageScreen(), '8_folders');
  });
}
