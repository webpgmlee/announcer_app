import 'package:announcer_app/analysis/script_layout.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:announcer_app/app.dart';
import 'package:announcer_app/audio/recorder.dart';
import 'package:announcer_app/data/database.dart';
import 'package:announcer_app/data/memo_repository.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/data/script_repository.dart';
import 'package:announcer_app/data/session_repository.dart';
import 'package:announcer_app/data/settings_repository.dart';
import 'package:announcer_app/speech/transcriber.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class IdleRecorder implements Recorder {
  final _done = Completer<RecordResult>();
  @override
  Future<RecordStart> start() async => RecordStart.permissionDenied;
  @override
  Stream<Float32List> get pcmFrames => const Stream.empty();
  @override
  Future<RecordResult> stop() => _done.future;
  @override
  Future<RecordResult> get finished => _done.future;
}

class NoTranscriber implements Transcriber {
  @override
  Future<Transcript> transcribe(String wavPath, {void Function(double progress)? onProgress}) async =>
      Transcript.empty;
}

void main() {
  sqfliteFfiInit();
  late Database db;
  late SessionRepository sessions;
  late ScriptRepository scripts;

  setUp(() async {
    db = await openAppDatabase(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
    sessions = SessionRepository(db);
    scripts = ScriptRepository(db, sessions);
  });
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        scriptRepositoryProvider.overrideWithValue(scripts),
        sessionRepositoryProvider.overrideWithValue(sessions),
        memoRepositoryProvider.overrideWithValue(MemoRepository(db)),
        recorderProvider.overrideWithValue(IdleRecorder()),
        transcriberProvider.overrideWithValue(NoTranscriber()),
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
      ],
      child: const AnnouncerApp(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('아래에 대본·녹음·기록 탭이 있고 처음은 대본 탭', (tester) async {
    await pumpApp(tester);
    expect(find.text('대본'), findsOneWidget);
    expect(find.text('녹음'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('연습할 원고를 붙여넣어 주세요'), findsOneWidget);
  });

  testWidgets('원고를 고르지 않으면 녹음·기록 탭이 안내한다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('녹음'));
    await tester.pumpAndSettle();
    expect(find.text('대본 탭에서 원고를 골라 주세요'), findsOneWidget);
    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(find.text('대본 탭에서 원고를 골라 주세요'), findsOneWidget);
  });

  testWidgets('대본 탭에서 원고를 누르면 녹음 탭에서 온에어 화면이 열린다', (tester) async {
    await scripts.add(Script(
        title: '9시 뉴스 오프닝',
        body: '시청자 여러분, 안녕하십니까. 9시 뉴스를 시작하겠습니다.',
        createdAt: DateTime(2026)));
    await pumpApp(tester);
    await tester.tap(find.text('9시 뉴스 오프닝'));
    await tester.pumpAndSettle();
    expect(find.text('온에어.'), findsOneWidget);
    expect(find.text('9시 뉴스 오프닝'), findsOneWidget);
    expect(find.text('ON AIR'), findsOneWidget);
    expect(find.text('시작하겠습니다.'), findsOneWidget);
    expect(find.text('//'), findsWidgets);
    expect(find.text('대본 0%'), findsOneWidget);
    expect(find.textContaining('점수'), findsNothing);
    expect(find.textContaining('채점'), findsNothing);
  });

  testWidgets('어절 사이를 눌러 끊어 읽기 표시를 바꾸면 저장된다', (tester) async {
    await scripts.add(Script(title: '뉴스', body: '먼저 오늘의 소식입니다', createdAt: DateTime(2026)));
    await pumpApp(tester);
    await tester.tap(find.text('뉴스'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gap-0')));
    await tester.pumpAndSettle();
    final s = (await scripts.all()).single;
    expect(await scripts.pauses(s), {0: Pause.pause});
    expect(find.text('/'), findsWidgets);
  });

  testWidgets('어절을 길게 눌러 메모를 저장하면 말풍선이 보인다', (tester) async {
    await scripts.add(Script(title: '뉴스', body: '먼저 오늘의 소식입니다', createdAt: DateTime(2026)));
    await pumpApp(tester);
    await tester.tap(find.text('뉴스'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('소식입니다'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '또렷하게');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('또렷하게'), findsOneWidget);
    final s = (await scripts.all()).single;
    expect((await MemoRepository(db).forScript(s.id!))[2]!.text, '또렷하게');
  });

  testWidgets('속도는 기본 350이고, + 를 누르면 360으로 저장되어 다시 열어도 남는다', (tester) async {
    await scripts.add(Script(title: '뉴스', body: '먼저 오늘의 소식입니다', createdAt: DateTime(2026)));
    await pumpApp(tester);
    await tester.tap(find.text('뉴스'));
    await tester.pumpAndSettle();
    expect(find.text('350'), findsOneWidget);
    expect(find.text('음절/분'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pace-plus')));
    await tester.pumpAndSettle();
    expect(find.text('360'), findsOneWidget);
    expect(await SettingsRepository(db).pace(), 360);

    await tester.tap(find.text('대본'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('뉴스'));
    await tester.pumpAndSettle();
    expect(find.text('360'), findsOneWidget);
  });

  testWidgets('속도를 바꾸면 남은 시간도 바뀐다', (tester) async {
    await scripts.add(Script(title: '뉴스', body: '먼저 오늘의 소식입니다', createdAt: DateTime(2026)));
    await pumpApp(tester);
    await tester.tap(find.text('뉴스'));
    await tester.pumpAndSettle();
    // 2+3+5 = 10음절: 350이면 약 1.7초 → 0:01, 200이면 3초 → 0:03
    expect(find.text('남은 0:01'), findsOneWidget);
    for (var i = 0; i < 15; i++) {
      await tester.tap(find.byKey(const ValueKey('pace-minus')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('200'), findsOneWidget);
    expect(find.text('남은 0:03'), findsOneWidget);
  });
}
