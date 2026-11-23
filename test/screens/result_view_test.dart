import 'package:announcer_app/analysis/compare.dart';
import 'package:announcer_app/analysis/intonation.dart';
import 'package:announcer_app/analysis/pitch.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/practice/practice_controller.dart';
import 'package:announcer_app/screens/result_screen.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final script = Script(id: 1, title: '경제', body: '경제가 성장했습니다', createdAt: DateTime(2026));
final session = PracticeSession(
  id: 3,
  scriptId: 1,
  audioPath: 'x.wav',
  elapsed: const Duration(minutes: 1, seconds: 5),
  syllablesPerMinute: 312.4,
  pitch: [
    for (var i = 0; i < 300; i++)
      PitchPoint(t: Duration(milliseconds: i * 10), hz: 180 + (i % 50).toDouble()),
  ],
  createdAt: DateTime(2026),
);
const intonation = IntonationReport(
  flatRanges: [DurationRange(Duration.zero, Duration(seconds: 3))],
  risingEnds: [Duration(seconds: 2)],
  noVoice: false,
);

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('인식 중(metricsReady)에도 시간·빠르기·억양을 먼저 보여준다', (tester) async {
    await pump(
        tester,
        ResultView(
          script: script,
          session: session,
          intonation: intonation,
          status: ResultStatus.metricsReady,
          progress: 0.4,
        ));
    expect(find.text('1:05'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('다르게 들린 단어'), findsOneWidget);
    expect(find.text('원고와 맞춰 보는 중이에요 (40%)'), findsOneWidget);
    expect(find.text('단조로운 구간 1곳'), findsOneWidget);
    expect(find.text('문장 끝이 올라간 곳 1곳'), findsOneWidget);
  });

  testWidgets('비교가 끝나면 원고 위에 표시한다', (tester) async {
    await pump(
        tester,
        ResultView(
          script: script,
          session: session,
          intonation: intonation,
          status: ResultStatus.complete,
          marks: const [
            WordMark(scriptWord: '경제가', status: MarkStatus.matched),
            WordMark(scriptWord: '성장했습니다', heardWord: '생장했습니다', status: MarkStatus.misheard),
          ],
        ));
    expect(find.text('성장했습니다'), findsOneWidget);
    expect(find.textContaining('맞춰 보는 중'), findsNothing);
  });

  testWidgets('무음이면 안내만 보여준다 (Review Focus 1)', (tester) async {
    var retried = false;
    await pump(
        tester,
        ResultView(
          script: script,
          status: ResultStatus.complete,
          message: noVoiceMessage,
          onRetry: () => retried = true,
        ));
    expect(find.text('목소리가 들리지 않았어요'), findsOneWidget);
    await tester.tap(find.text('다시 연습'));
    expect(retried, isTrue);
  });

  testWidgets('녹음이 끊겼으면 알려준다', (tester) async {
    await pump(
        tester,
        ResultView(
          script: script,
          session: session,
          intonation: intonation,
          status: ResultStatus.complete,
          interrupted: true,
        ));
    expect(find.text('녹음이 중간에 끊겨서 그때까지 저장했어요'), findsOneWidget);
  });

  testWidgets('화면에 "점수", "채점"이라는 말이 없다', (tester) async {
    await pump(
        tester,
        ResultView(
          script: script,
          session: session,
          intonation: intonation,
          status: ResultStatus.complete,
          marks: const [WordMark(scriptWord: '경제가', status: MarkStatus.matched)],
        ));
    expect(find.textContaining('점수'), findsNothing);
    expect(find.textContaining('채점'), findsNothing);
  });
}
