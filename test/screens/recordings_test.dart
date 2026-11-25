import 'dart:io';

import 'package:announcer_app/analysis/pitch.dart';
import 'package:announcer_app/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late TestStore store;
  late Directory dir;
  setUp(() async {
    store = await TestStore.open();
    dir = Directory.systemTemp.createTempSync('recordings_test');
  });
  tearDown(() async {
    await store.close();
    dir.deleteSync(recursive: true);
  });

  Future<int> addScript(String title) =>
      store.scripts.add(Script(title: title, body: '안녕하십니까', createdAt: DateTime(2026)));

  Future<String> addSession(int scriptId, DateTime at, Duration elapsed, double spm) async {
    final f = File('${dir.path}/${at.millisecondsSinceEpoch}.wav')..writeAsBytesSync([0]);
    await store.sessions.add(PracticeSession(
      scriptId: scriptId,
      audioPath: f.path,
      elapsed: elapsed,
      syllablesPerMinute: spm,
      pitch: const [PitchPoint(t: Duration.zero, hz: 200)],
      createdAt: at,
    ));
    return f.path;
  }

  Future<void> openRecordings(WidgetTester tester) async {
    await store.pumpApp(tester);
    await tester.tap(find.text('녹음관리'));
    await tester.pumpAndSettle();
  }

  testWidgets('녹음이 없으면 안내 (Review Focus 4)', (tester) async {
    await openRecordings(tester);
    expect(find.text('아직 연습 기록이 없어요'), findsOneWidget);
  });

  testWidgets('모든 원고의 녹음이 최신순으로 제목·날짜·시간·분당 음절과 함께', (tester) async {
    final a = await addScript('날씨');
    final b = await addScript('경제');
    await addSession(a, DateTime(2026, 11, 20, 9, 5), const Duration(seconds: 58), 301.2);
    await addSession(b, DateTime(2026, 11, 22, 21, 30), const Duration(minutes: 1, seconds: 4), 287.6);
    await openRecordings(tester);

    final newer = find.text('경제');
    final older = find.text('날씨');
    expect(tester.getTopLeft(newer).dy, lessThan(tester.getTopLeft(older).dy));
    expect(find.text('2026.11.22 21:30 · 1:04 · 1분당 288음절'), findsOneWidget);
    expect(find.text('2026.11.20 09:05 · 0:58 · 1분당 301음절'), findsOneWidget);
  });

  testWidgets('누르면 결과 화면이 열린다', (tester) async {
    final a = await addScript('날씨');
    await addSession(a, DateTime(2026, 11, 20, 9, 5), const Duration(seconds: 58), 301);
    await openRecordings(tester);
    await tester.tap(find.text('날씨'));
    await tester.pumpAndSettle();
    expect(find.text('걸린 시간'), findsOneWidget);
    expect(find.text('0:58'), findsOneWidget);
  });

  testWidgets('밀어서 확인하면 지워지고 녹음 파일도 지워진다', (tester) async {
    final a = await addScript('날씨');
    final path = await addSession(a, DateTime(2026, 11, 20, 9, 5), const Duration(seconds: 58), 301);
    await openRecordings(tester);
    await tester.drag(find.text('날씨'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(find.text('날씨'), findsNothing);
    expect(await store.sessions.all(), isEmpty);
    expect(File(path).existsSync(), isFalse);
  });

  testWidgets('취소하면 남는다', (tester) async {
    final a = await addScript('날씨');
    await addSession(a, DateTime(2026, 11, 20, 9, 5), const Duration(seconds: 58), 301);
    await openRecordings(tester);
    await tester.drag(find.text('날씨'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('날씨'), findsOneWidget);
  });

  testWidgets('원고를 지우면 녹음관리에서도 사라진다 (Review Focus 5)', (tester) async {
    final a = await addScript('날씨');
    await addSession(a, DateTime(2026, 11, 20, 9, 5), const Duration(seconds: 58), 301);
    await store.scripts.delete(a);
    await openRecordings(tester);
    expect(find.text('아직 연습 기록이 없어요'), findsOneWidget);
  });
}
