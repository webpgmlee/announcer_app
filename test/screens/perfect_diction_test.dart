import 'package:announcer_app/analysis/compare.dart';
import 'package:announcer_app/analysis/diction_score.dart';
import 'package:announcer_app/data/challenge_repository.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/data/twisters.dart';
import 'package:announcer_app/screens/challenge_result_view.dart';
import 'package:announcer_app/screens/perfect_diction_screen.dart';
import 'package:announcer_app/theme.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

DictionScore score(int total, {bool perfect = false}) => DictionScore(
      total: total,
      accuracy: 92,
      speed: 88,
      measuredPace: 312,
      stars: starsFor(total),
      perfect: perfect,
    );

void main() {
  late TestStore store;
  setUp(() async => store = await TestStore.open());
  tearDown(() => store.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: store.overrides,
      child: MaterialApp(theme: buildTheme(), home: const PerfectDictionScreen()),
    ));
    await tester.pumpAndSettle();
  }

  final stage1 = twisters.where((t) => t.stage == 1).toList();
  final stage2 = twisters.where((t) => t.stage == 2).toList();

  group('도전 목록', () {
    testWidgets('잰말놀이·내 원고 탭과 모은 별 수', (tester) async {
      await pump(tester);
      expect(find.text('잰말놀이'), findsOneWidget);
      expect(find.text('내 원고'), findsOneWidget);
      expect(find.text('★ 0 / 45'), findsOneWidget);
      expect(find.text(stage1.first.title), findsOneWidget);
      expect(find.text('1단계 · 목표 300음절/분'), findsOneWidget);
    });

    testWidgets('2단계는 잠겨 있고 눌러도 도전이 시작되지 않는다 (Review Focus 4)', (tester) async {
      await pump(tester);
      await tester.scrollUntilVisible(find.text(stage2.first.title), 300,
          scrollable: find
              .descendant(
                  of: find.byKey(const ValueKey('twister-list')),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.textContaining('별 5개를 모으면 열려요'), findsWidgets);
      await tester.tap(find.text(stage2.first.title));
      await tester.pumpAndSettle();
      expect(find.text('앞 단계에서 별을 5개 모아 주세요'), findsOneWidget);
      expect(find.text('온에어.'), findsNothing);
      expect(find.text('ON AIR'), findsNothing); // 도전 화면이 열리지 않았다
    });

    testWidgets('앞 단계 별 5개면 다음 단계가 열리고 최고 점수·별이 보인다', (tester) async {
      await store.challenges.add(twisterKey(stage1[0].id), score(96));
      await store.challenges.add(twisterKey(stage1[1].id), score(88));
      await pump(tester);
      expect(find.text('★ 5 / 45'), findsOneWidget);
      expect(find.text('96'), findsOneWidget);
      await tester.scrollUntilVisible(find.text(stage2.first.title), 300,
          scrollable: find
              .descendant(
                  of: find.byKey(const ValueKey('twister-list')),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.textContaining('별 5개를 모으면 열려요'), findsNothing);
    });

    testWidgets('열린 잰말놀이를 누르면 도전 화면이 열린다', (tester) async {
      await pump(tester);
      await tester.tap(find.text(stage1.first.title));
      await tester.pumpAndSettle();
      expect(find.text('목표 300음절/분'), findsOneWidget);
      expect(find.text('ON AIR'), findsOneWidget);
    });

    testWidgets('내 원고 탭에는 원고관리의 원고가 나온다', (tester) async {
      await store.scripts.add(Script(title: '초급 · 날씨 소식', body: '맑겠습니다.', createdAt: DateTime(2026)));
      await pump(tester);
      await tester.tap(find.text('내 원고'));
      await tester.pumpAndSettle();
      expect(find.text('날씨 소식'), findsOneWidget);
    });
  });

  group('도전 결과', () {
    Future<void> pumpResult(WidgetTester tester, DictionScore s,
        {VoidCallback? onRetry, bool newBest = false}) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: ChallengeResultView(
            score: s,
            targetPace: 300,
            marks: const [
              WordMark(scriptWord: '간장', status: MarkStatus.matched),
              WordMark(scriptWord: '공장', heardWord: '공정', status: MarkStatus.misheard),
            ],
            newBest: newBest,
            onRetry: onRetry ?? () {},
            onExit: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('딕션 점수, 별, 정확도·속도, 다르게 들린 단어', (tester) async {
      await pumpResult(tester, score(88));
      expect(find.text('88'), findsOneWidget);
      expect(find.text('딕션 점수'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(1));
      expect(find.text('정확도 (음성 인식 기준)'), findsOneWidget);
      expect(find.text('92'), findsOneWidget);
      expect(find.text('312음절/분 (목표 300)'), findsOneWidget);
      expect(find.text('다르게 들린 단어'), findsOneWidget);
      expect(find.text('PERFECT'), findsNothing);
      expect(find.textContaining('발음 점수'), findsNothing);
      expect(find.textContaining('채점'), findsNothing);
    });

    testWidgets('PERFECT와 최고 기록 표시', (tester) async {
      await pumpResult(tester, score(100, perfect: true), newBest: true);
      expect(find.text('PERFECT'), findsOneWidget);
      expect(find.text('최고 기록!'), findsOneWidget);
    });

    testWidgets('다시 도전 버튼', (tester) async {
      var retried = false;
      await pumpResult(tester, score(50), onRetry: () => retried = true);
      await tester.tap(find.text('다시 도전'));
      expect(retried, isTrue);
    });
  });
}
