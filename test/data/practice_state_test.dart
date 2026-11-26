import 'dart:io';

import 'package:announcer_app/analysis/pitch.dart';
import 'package:announcer_app/data/database.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/data/practice_state.dart';
import 'package:announcer_app/data/script_repository.dart';
import 'package:announcer_app/data/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late SessionRepository sessions;
  late ScriptRepository scripts;

  setUp(() async {
    db = await openAppDatabase(inMemoryDatabasePath, factory: databaseFactoryFfi);
    sessions = SessionRepository(db);
    scripts = ScriptRepository(db, sessions);
  });
  tearDown(() => db.close());

  Future<Script> addScript(String title) async {
    final id = await scripts.add(Script(title: title, body: '본문입니다.', createdAt: DateTime(2026)));
    return (await scripts.all()).firstWhere((s) => s.id == id);
  }

  Future<void> record(int scriptId, DateTime at) => sessions.add(PracticeSession(
        scriptId: scriptId,
        audioPath: 'x_${at.microsecondsSinceEpoch}.wav',
        elapsed: const Duration(seconds: 5),
        syllablesPerMinute: 300,
        pitch: const [PitchPoint(t: Duration.zero, hz: 200)],
        createdAt: at,
      ));

  test('스키마 버전은 6', () async {
    expect(currentSchemaVersion, 6);
    expect(await db.getVersion(), 6);
  });

  test('원고별 녹음 횟수와 마지막 연습 시각', () async {
    final a = await addScript('가');
    final b = await addScript('나');
    await record(a.id!, DateTime(2026, 11, 1));
    await record(a.id!, DateTime(2026, 11, 3));
    final stats = await sessions.practiceStats();
    expect(stats[a.id]!.count, 2);
    expect(stats[a.id]!.last, DateTime(2026, 11, 3));
    expect(stats.containsKey(b.id), isFalse);
  });

  group('연습 중 판단', () {
    test('녹음한 적 없으면 연습 중이 아니다', () async {
      final s = await addScript('가');
      expect(isPracticing(s, null), isFalse);
    });

    test('녹음하면 자동으로 연습 중', () async {
      final s = await addScript('가');
      await record(s.id!, DateTime(2026, 11, 1));
      expect(isPracticing(s, (await sessions.practiceStats())[s.id]), isTrue);
    });

    test('연습 완료를 누르면 연습 중이 아니다', () async {
      final s = await addScript('가');
      await record(s.id!, DateTime(2026, 11, 1));
      await scripts.markCompleted(s.id!, at: DateTime(2026, 11, 2));
      final after = (await scripts.all()).single;
      expect(after.completedAt, DateTime(2026, 11, 2));
      expect(isPracticing(after, (await sessions.practiceStats())[s.id]), isFalse);
    });

    test('완료한 뒤 다시 녹음하면 다시 연습 중', () async {
      final s = await addScript('가');
      await record(s.id!, DateTime(2026, 11, 1));
      await scripts.markCompleted(s.id!, at: DateTime(2026, 11, 2));
      await record(s.id!, DateTime(2026, 11, 5));
      final after = (await scripts.all()).single;
      expect(isPracticing(after, (await sessions.practiceStats())[s.id]), isTrue);
    });

    test('복제한 원고는 녹음이 없으니 연습 중이 아니다', () async {
      final s = await addScript('가');
      await record(s.id!, DateTime(2026, 11, 1));
      final copyId = await scripts.duplicate(s);
      final copy = (await scripts.all()).firstWhere((x) => x.id == copyId);
      expect(isPracticing(copy, (await sessions.practiceStats())[copyId]), isFalse);
    });
  });

  test('v5 DB를 v6로 열어도 원고가 남고 완료 시각은 비어 있다', () async {
    final dir = Directory.systemTemp.createTempSync('v6_upgrade');
    final path = p.join(dir.path, 'up.db');
    final v5 = await openAppDatabase(path, factory: databaseFactoryFfi, version: 5);
    await v5.insert('scripts', {'title': 't', 'body': '본문', 'is_premium': 0, 'created_at': 0});
    await v5.close();
    final v6 = await openAppDatabase(path, factory: databaseFactoryFfi);
    final s = (await ScriptRepository(v6, SessionRepository(v6)).all()).single;
    expect(s.body, '본문');
    expect(s.completedAt, isNull);
    await v6.close();
    dir.deleteSync(recursive: true);
  });
}
