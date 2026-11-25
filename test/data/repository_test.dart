import 'dart:io';

import 'package:announcer_app/analysis/compare.dart';
import 'package:announcer_app/analysis/pitch.dart';
import 'package:announcer_app/data/database.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/data/script_repository.dart';
import 'package:announcer_app/data/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  late Database db;
  late ScriptRepository scripts;
  late SessionRepository sessions;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('announcer_test');
    db = await openAppDatabase(inMemoryDatabasePath, factory: databaseFactoryFfi);
    sessions = SessionRepository(db);
    scripts = ScriptRepository(db, sessions);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Script script(String body, {String title = '제목'}) =>
      Script(title: title, body: body, createdAt: DateTime(2026, 11, 23, 9));

  Future<File> audio(String name) async =>
      File(p.join(tmp.path, name))..writeAsBytesSync([1, 2, 3]);

  PracticeSession session(int scriptId, String audioPath, {DateTime? at}) =>
      PracticeSession(
        scriptId: scriptId,
        audioPath: audioPath,
        elapsed: const Duration(seconds: 61, milliseconds: 500),
        syllablesPerMinute: 312.5,
        pitch: const [
          PitchPoint(t: Duration.zero, hz: null),
          PitchPoint(t: Duration(milliseconds: 10), hz: 201.5),
        ],
        createdAt: at ?? DateTime(2026, 11, 23, 10),
      );

  group('ScriptRepository', () {
    test('원고 추가 후 조회 (모든 칸 유지)', () async {
      final id = await scripts.add(Script(
        title: '날씨',
        body: '오늘은 맑겠습니다.',
        category: '날씨',
        difficulty: 2,
        isPremium: false,
        createdAt: DateTime(2026, 11, 23, 9),
      ));
      final all = await scripts.all();
      expect(all, hasLength(1));
      final s = all.single;
      expect(s.id, id);
      expect(s.title, '날씨');
      expect(s.body, '오늘은 맑겠습니다.');
      expect(s.category, '날씨');
      expect(s.difficulty, 2);
      expect(s.isPremium, isFalse);
      expect(s.createdAt, DateTime(2026, 11, 23, 9));
    });

    test('본문이 공백뿐인 원고는 ArgumentError (Review Focus 4)', () async {
      expect(() => scripts.add(script('  \n\t ')), throwsArgumentError);
      expect(await scripts.all(), isEmpty);
    });

    test('목록은 최근 것부터', () async {
      await scripts.add(Script(title: '옛것', body: '가', createdAt: DateTime(2026, 1, 1)));
      await scripts.add(Script(title: '새것', body: '나', createdAt: DateTime(2026, 2, 1)));
      expect((await scripts.all()).map((s) => s.title), ['새것', '옛것']);
    });

    test('원고를 지우면 그 연습 기록과 오디오도 지워진다', () async {
      final id = await scripts.add(script('본문'));
      final f = await audio('a.wav');
      await sessions.add(session(id, f.path));
      await scripts.delete(id);
      expect(await scripts.all(), isEmpty);
      expect(await sessions.forScript(id), isEmpty);
      expect(f.existsSync(), isFalse);
    });
  });

  group('SessionRepository', () {
    test('세션 저장 후 forScript로 조회', () async {
      final id = await scripts.add(script('본문'));
      final f = await audio('a.wav');
      final sid = await sessions.add(session(id, f.path));
      final list = await sessions.forScript(id);
      expect(list, hasLength(1));
      final s = list.single;
      expect(s.id, sid);
      expect(s.audioPath, f.path);
      expect(s.elapsed, const Duration(seconds: 61, milliseconds: 500));
      expect(s.syllablesPerMinute, 312.5);
      expect(s.pitch.map((e) => (e.t, e.hz)),
          [(Duration.zero, null), (const Duration(milliseconds: 10), 201.5)]);
      expect(s.marks, isNull);
    });

    test('forScript는 최신순이고 다른 원고 기록은 섞이지 않는다', () async {
      final a = await scripts.add(script('가'));
      final b = await scripts.add(script('나'));
      await sessions.add(session(a, 'x', at: DateTime(2026, 1, 1)));
      await sessions.add(session(a, 'y', at: DateTime(2026, 3, 1)));
      await sessions.add(session(b, 'z'));
      expect((await sessions.forScript(a)).map((s) => s.audioPath), ['y', 'x']);
    });

    test('updateMarks로 비교 결과와 인식 글을 채운다', () async {
      final id = await scripts.add(script('본문'));
      final sid = await sessions.add(session(id, 'x'));
      await sessions.updateMarks(sid, const [
        WordMark(scriptWord: '경제가', status: MarkStatus.matched),
        WordMark(scriptWord: '성장', heardWord: '생장', status: MarkStatus.misheard),
        WordMark(scriptWord: '', heardWord: '아주', status: MarkStatus.extra),
      ], transcript: '경제가 생장 아주');
      final s = (await sessions.forScript(id)).single;
      expect(s.transcript, '경제가 생장 아주');
      expect(s.marks!.map((m) => (m.scriptWord, m.heardWord, m.status, m.score)), [
        ('경제가', null, MarkStatus.matched, null),
        ('성장', '생장', MarkStatus.misheard, null),
        ('', '아주', MarkStatus.extra, null),
      ]);
    });

    test('세션 삭제 시 오디오 파일도 삭제', () async {
      final id = await scripts.add(script('본문'));
      final f = await audio('a.wav');
      final sid = await sessions.add(session(id, f.path));
      await sessions.delete(sid);
      expect(await sessions.forScript(id), isEmpty);
      expect(f.existsSync(), isFalse);
    });

    test('오디오 파일이 이미 없어도 삭제는 성공한다', () async {
      final id = await scripts.add(script('본문'));
      final sid = await sessions.add(session(id, p.join(tmp.path, 'gone.wav')));
      await sessions.delete(sid);
      expect(await sessions.forScript(id), isEmpty);
    });
  });

  test('스키마 v1 DB에 데이터를 넣고 v2로 열어도 데이터 유지 (Review Focus 5)', () async {
    final path = p.join(tmp.path, 'upgrade.db');
    final v1 = await openAppDatabase(path, factory: databaseFactoryFfi, version: 1);
    // 옛 DB에는 옛 구조 그대로 넣는다 (최신 저장 코드는 새 칸까지 쓴다).
    final id = await v1.insert('scripts', {
      'title': '제목',
      'body': '예전 원고',
      'is_premium': 0,
      'created_at': DateTime(2026, 11, 23, 9).millisecondsSinceEpoch,
    });
    await v1.insert('sessions', {
      'script_id': id,
      'audio_path': 'old.wav',
      'elapsed_ms': 1000,
      'spm': 300.0,
      'pitch_json': '[]',
      'created_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
    });
    await v1.close();

    final v2 = await openAppDatabase(path, factory: databaseFactoryFfi);
    expect(await v2.getVersion(), currentSchemaVersion);
    expect(currentSchemaVersion, greaterThanOrEqualTo(2));
    final s2 = SessionRepository(v2);
    final scriptsAfter = await ScriptRepository(v2, s2).all();
    expect(scriptsAfter.single.body, '예전 원고');
    final old = (await s2.forScript(id)).single;
    expect(old.audioPath, 'old.wav');
    expect(old.transcript, isNull);
    await v2.close();
  });
}
