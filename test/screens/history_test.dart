import 'dart:io';

import 'package:announcer_app/analysis/pitch.dart';
import 'package:announcer_app/app.dart';
import 'package:announcer_app/data/database.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/data/script_repository.dart';
import 'package:announcer_app/data/session_repository.dart';
import 'package:announcer_app/screens/history_screen.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late SessionRepository sessions;
  late Script script;
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('history_test');
    db = await openAppDatabase(inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate);
    sessions = SessionRepository(db);
    final scripts = ScriptRepository(db, sessions);
    final id = await scripts.add(
        Script(title: '날씨', body: '오늘은 맑겠습니다', createdAt: DateTime(2026, 11, 1)));
    script = (await scripts.all()).single;
    expect(script.id, id);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<int> addSession(DateTime at, Duration elapsed, double spm) {
    final f = File('${dir.path}/${at.millisecondsSinceEpoch}.wav')..writeAsBytesSync([0]);
    return sessions.add(PracticeSession(
      scriptId: script.id!,
      audioPath: f.path,
      elapsed: elapsed,
      syllablesPerMinute: spm,
      pitch: const [PitchPoint(t: Duration.zero, hz: 200)],
      createdAt: at,
    ));
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(sessions),
        scriptRepositoryProvider.overrideWithValue(ScriptRepository(db, sessions)),
      ],
      child: MaterialApp(home: HistoryScreen(script: script)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('원고별 기록이 최신순으로, 날짜·시간·분당 음절과 함께 나온다', (tester) async {
    await addSession(DateTime(2026, 11, 20, 9, 5), const Duration(seconds: 58), 301.2);
    await addSession(DateTime(2026, 11, 22, 21, 30), const Duration(minutes: 1, seconds: 4), 287.6);
    await pump(tester);

    final newer = find.text('2026.11.22 21:30');
    final older = find.text('2026.11.20 09:05');
    expect(newer, findsOneWidget);
    expect(older, findsOneWidget);
    expect(tester.getTopLeft(newer).dy, lessThan(tester.getTopLeft(older).dy));
    expect(find.text('1:04 · 1분당 288음절'), findsOneWidget);
    expect(find.text('0:58 · 1분당 301음절'), findsOneWidget);
  });

  testWidgets('기록이 없으면 안내가 나온다', (tester) async {
    await pump(tester);
    expect(find.text('아직 연습 기록이 없어요'), findsOneWidget);
  });

  testWidgets('밀어서 삭제하면 사라지고 녹음 파일도 지워진다', (tester) async {
    await addSession(DateTime(2026, 11, 20, 9, 5), const Duration(seconds: 58), 301);
    await pump(tester);
    final audio = (await sessions.forScript(script.id!)).single.audioPath;

    await tester.drag(find.text('2026.11.20 09:05'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    expect(find.text('2026.11.20 09:05'), findsNothing);
    expect(await sessions.forScript(script.id!), isEmpty);
    expect(File(audio).existsSync(), isFalse);
  });

  testWidgets('삭제 확인에서 취소하면 남는다', (tester) async {
    await addSession(DateTime(2026, 11, 20, 9, 5), const Duration(seconds: 58), 301);
    await pump(tester);
    await tester.drag(find.text('2026.11.20 09:05'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('2026.11.20 09:05'), findsOneWidget);
    expect(await sessions.forScript(script.id!), hasLength(1));
  });
}
