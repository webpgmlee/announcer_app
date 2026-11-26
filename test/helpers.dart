import 'dart:async';
import 'dart:typed_data';

import 'package:announcer_app/app.dart';
import 'package:announcer_app/audio/recorder.dart';
import 'package:announcer_app/data/challenge_repository.dart';
import 'package:announcer_app/data/database.dart';
import 'package:announcer_app/data/folder_repository.dart';
import 'package:announcer_app/data/memo_repository.dart';
import 'package:announcer_app/data/script_repository.dart';
import 'package:announcer_app/data/session_repository.dart';
import 'package:announcer_app/data/settings_repository.dart';
import 'package:announcer_app/speech/transcriber.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 화면 테스트에서 마이크를 쓰지 않는 녹음기 (권한 거부로 응답).
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
  Future<Transcript> transcribe(String wavPath,
          {void Function(double progress)? onProgress}) async =>
      Transcript.empty;
}

/// 메모리 DB와 저장소 묶음.
class TestStore {
  TestStore._(this.db)
      : sessions = SessionRepository(db),
        folders = FolderRepository(db),
        memos = MemoRepository(db),
        settings = SettingsRepository(db),
        challenges = ChallengeRepository(db) {
    scripts = ScriptRepository(db, sessions);
  }

  static Future<TestStore> open() async {
    sqfliteFfiInit();
    return TestStore._(
        await openAppDatabase(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate));
  }

  final Database db;
  final SessionRepository sessions;
  final FolderRepository folders;
  final MemoRepository memos;
  final SettingsRepository settings;
  final ChallengeRepository challenges;
  late final ScriptRepository scripts;

  List<Override> get overrides => [
        scriptRepositoryProvider.overrideWithValue(scripts),
        sessionRepositoryProvider.overrideWithValue(sessions),
        folderRepositoryProvider.overrideWithValue(folders),
        memoRepositoryProvider.overrideWithValue(memos),
        settingsRepositoryProvider.overrideWithValue(settings),
        challengeRepositoryProvider.overrideWithValue(challenges),
        recorderProvider.overrideWithValue(IdleRecorder()),
        transcriberProvider.overrideWithValue(NoTranscriber()),
      ];

  /// 시작 화면을 지나 메인 메뉴까지 띄운다.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(overrides: overrides, child: const AnnouncerApp()));
    await tester.pumpAndSettle();
  }

  Future<void> close() => db.close();
}
