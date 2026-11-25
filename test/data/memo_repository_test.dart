import 'dart:io';

import 'package:announcer_app/analysis/script_layout.dart';
import 'package:announcer_app/data/database.dart';
import 'package:announcer_app/data/memo_repository.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/data/script_repository.dart';
import 'package:announcer_app/data/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late ScriptRepository scripts;
  late MemoRepository memos;

  setUp(() async {
    db = await openAppDatabase(inMemoryDatabasePath, factory: databaseFactoryFfi);
    scripts = ScriptRepository(db, SessionRepository(db));
    memos = MemoRepository(db);
  });
  tearDown(() => db.close());

  Future<Script> addScript(String body) async {
    final id = await scripts.add(Script(title: 't', body: body, createdAt: DateTime(2026)));
    return (await scripts.all()).firstWhere((s) => s.id == id);
  }

  Memo memo(int scriptId, int word, String text, [MemoKind kind = MemoKind.pronunciation]) =>
      Memo(scriptId: scriptId, wordIndex: word, kind: kind, text: text, createdAt: DateTime(2026));

  test('스키마 버전은 3 이상 (메모 테이블이 생긴 버전)', () async {
    expect(currentSchemaVersion, greaterThanOrEqualTo(3));
    expect(await db.getVersion(), currentSchemaVersion);
  });

  test('끊어 읽기 표시: 처음 열면 자동으로 만들어 저장한다', () async {
    final s = await addScript('안녕하십니까. 11월 23일, 9시 뉴스');
    expect(await scripts.pauses(s), {0: Pause.breath, 2: Pause.pause});
    final row = await db.query('scripts', columns: ['pause_json'], where: 'id = ?', whereArgs: [s.id]);
    expect(row.single['pause_json'], isNotNull);
  });

  test('끊어 읽기 표시를 고쳐 저장하면 그대로 돌아온다', () async {
    final s = await addScript('안녕하십니까. 11월 23일, 9시 뉴스');
    await scripts.setPauses(s.id!, {1: Pause.pause, 4: Pause.breath});
    expect(await scripts.pauses(s), {1: Pause.pause, 4: Pause.breath});
    await scripts.setPauses(s.id!, {});
    expect(await scripts.pauses(s), isEmpty); // 빈 표시도 자동으로 되살리지 않는다
  });

  test('메모 저장·교체·빈 글이면 삭제', () async {
    final s = await addScript('시작하겠습니다 먼저');
    await memos.save(memo(s.id!, 0, "받침 'ㅆ' 또렷하게"));
    var all = await memos.forScript(s.id!);
    expect(all.keys, [0]);
    expect(all[0]!.text, "받침 'ㅆ' 또렷하게");
    expect(all[0]!.kind, MemoKind.pronunciation);

    await memos.save(memo(s.id!, 0, '천천히', MemoKind.speed));
    all = await memos.forScript(s.id!);
    expect(all, hasLength(1));
    expect(all[0]!.kind, MemoKind.speed);
    expect(all[0]!.text, '천천히');

    await memos.save(memo(s.id!, 0, '   '));
    expect(await memos.forScript(s.id!), isEmpty);
  });

  test('메모 종류 이름', () {
    expect(MemoKind.values.map((k) => k.label), ['발음', '속도', '억양', '강조']);
  });

  test('원고를 지우면 그 원고 메모만 지워진다 (Review Focus 5)', () async {
    final a = await addScript('가 나');
    final b = await addScript('다 라');
    await memos.save(memo(a.id!, 0, 'a메모'));
    await memos.save(memo(b.id!, 1, 'b메모'));
    await scripts.delete(a.id!);
    expect(await memos.forScript(a.id!), isEmpty);
    expect((await memos.forScript(b.id!))[1]!.text, 'b메모');
  });

  test('v2 DB를 v3로 열어도 원고·기록이 남고 표시는 자동 생성 (Review Focus 4)', () async {
    final dir = Directory.systemTemp.createTempSync('v3_upgrade');
    final path = p.join(dir.path, 'up.db');
    final v2 = await openAppDatabase(path, factory: databaseFactoryFfi, version: 2);
    final id = await v2.insert('scripts', {
      'title': '예전',
      'body': '안녕하십니까. 뉴스입니다.',
      'is_premium': 0,
      'created_at': 0,
    });
    await v2.insert('sessions', {
      'script_id': id,
      'audio_path': 'old.wav',
      'elapsed_ms': 1000,
      'spm': 300.0,
      'pitch_json': '[]',
      'created_at': 0,
      'transcript': '안녕하십니까',
    });
    await v2.close();

    final v3 = await openAppDatabase(path, factory: databaseFactoryFfi);
    final sessions = SessionRepository(v3);
    final repo = ScriptRepository(v3, sessions);
    final s = (await repo.all()).single;
    expect(s.body, '안녕하십니까. 뉴스입니다.');
    expect((await sessions.forScript(id)).single.transcript, '안녕하십니까');
    expect(await repo.pauses(s), {0: Pause.breath, 1: Pause.breath});
    expect(await MemoRepository(v3).forScript(id), isEmpty);
    await v3.close();
    dir.deleteSync(recursive: true);
  });
}
