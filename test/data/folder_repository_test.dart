import 'dart:io';

import 'package:announcer_app/analysis/pitch.dart';
import 'package:announcer_app/analysis/script_layout.dart';
import 'package:announcer_app/data/database.dart';
import 'package:announcer_app/data/folder_repository.dart';
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
  late FolderRepository folders;
  late ScriptRepository scripts;
  late SessionRepository sessions;
  late MemoRepository memos;

  setUp(() async {
    db = await openAppDatabase(inMemoryDatabasePath, factory: databaseFactoryFfi);
    folders = FolderRepository(db);
    sessions = SessionRepository(db);
    scripts = ScriptRepository(db, sessions);
    memos = MemoRepository(db);
  });
  tearDown(() => db.close());

  Future<Script> addScript(String title, {int? folderId, DateTime? at}) async {
    final id = await scripts.add(Script(
        title: title,
        body: '안녕하십니까. 뉴스입니다.',
        folderId: folderId,
        createdAt: at ?? DateTime(2026)));
    return (await scripts.all()).firstWhere((s) => s.id == id);
  }

  PracticeSession session(int scriptId, DateTime at) => PracticeSession(
        scriptId: scriptId,
        audioPath: 'x_${at.millisecondsSinceEpoch}.wav',
        elapsed: const Duration(seconds: 10),
        syllablesPerMinute: 320,
        pitch: const [PitchPoint(t: Duration.zero, hz: 200)],
        createdAt: at,
      );

  test('스키마 버전은 5 이상 (폴더 테이블이 생긴 버전)', () async {
    expect(currentSchemaVersion, greaterThanOrEqualTo(5));
    expect(await db.getVersion(), currentSchemaVersion);
  });

  group('폴더', () {
    test('추가하면 만든 순서대로 조회된다', () async {
      await folders.add('뉴스');
      await folders.add('날씨');
      expect((await folders.all()).map((f) => f.name), ['뉴스', '날씨']);
    });

    test('빈 이름·같은 이름은 만들 수 없다 (Review Focus 2)', () async {
      await folders.add('뉴스');
      expect(() => folders.add('  '), throwsArgumentError);
      expect(() => folders.add(' 뉴스 '), throwsArgumentError);
      expect(await folders.all(), hasLength(1));
    });

    test('이름을 바꿀 수 있고, 다른 폴더와 겹치면 안 된다', () async {
      final a = await folders.add('뉴스');
      await folders.add('날씨');
      await folders.rename(a, '아침 뉴스');
      expect((await folders.all()).first.name, '아침 뉴스');
      expect(() => folders.rename(a, '날씨'), throwsArgumentError);
      expect(() => folders.rename(a, ''), throwsArgumentError);
      await folders.rename(a, '아침 뉴스'); // 자기 이름 그대로는 괜찮다
    });

    test('폴더를 지워도 안의 원고와 녹음은 남고 폴더 없음이 된다 (Review Focus 1)', () async {
      final f = await folders.add('뉴스');
      final s = await addScript('원고', folderId: f);
      await sessions.add(session(s.id!, DateTime(2026, 1, 1)));
      await folders.delete(f);
      expect(await folders.all(), isEmpty);
      final after = (await scripts.all()).single;
      expect(after.folderId, isNull);
      expect(await sessions.forScript(s.id!), hasLength(1));
    });
  });

  group('원고', () {
    test('폴더를 지정해 추가하고, 다른 폴더로 옮기고, 폴더에서 뺄 수 있다', () async {
      final a = await folders.add('뉴스');
      final b = await folders.add('날씨');
      final s = await addScript('원고', folderId: a);
      expect(s.folderId, a);
      await scripts.moveToFolder(s.id!, b);
      expect((await scripts.all()).single.folderId, b);
      await scripts.moveToFolder(s.id!, null);
      expect((await scripts.all()).single.folderId, isNull);
    });

    test('복제하면 제목에 (복사본)이 붙고 표시·메모·폴더를 복사, 녹음은 복사하지 않는다', () async {
      final f = await folders.add('뉴스');
      final s = await addScript('원고', folderId: f);
      await scripts.setPauses(s.id!, {1: Pause.pause});
      await memos.save(Memo(
          scriptId: s.id!,
          wordIndex: 0,
          kind: MemoKind.emphasis,
          text: '힘주어',
          createdAt: DateTime(2026)));
      await sessions.add(session(s.id!, DateTime(2026, 1, 1)));

      final copyId = await scripts.duplicate(s);
      final copy = (await scripts.all()).firstWhere((x) => x.id == copyId);
      expect(copy.title, '원고 (복사본)');
      expect(copy.body, s.body);
      expect(copy.folderId, f);
      expect(await scripts.pauses(copy), {1: Pause.pause});
      expect((await memos.forScript(copyId))[0]!.text, '힘주어');
      expect(await sessions.forScript(copyId), isEmpty);
    });

    test('복제본의 메모·표시를 바꿔도 원본은 그대로 (Review Focus 3)', () async {
      final s = await addScript('원고');
      await scripts.setPauses(s.id!, {1: Pause.pause});
      await memos.save(Memo(
          scriptId: s.id!, wordIndex: 0, kind: MemoKind.speed, text: '천천히', createdAt: DateTime(2026)));
      final copyId = await scripts.duplicate(s);
      await scripts.setPauses(copyId, {});
      await memos.save(Memo(
          scriptId: copyId, wordIndex: 0, kind: MemoKind.speed, text: '', createdAt: DateTime(2026)));
      expect(await scripts.pauses(s), {1: Pause.pause});
      expect((await memos.forScript(s.id!))[0]!.text, '천천히');
    });
  });

  test('모든 원고의 녹음을 최신순으로 조회한다', () async {
    final a = await addScript('가');
    final b = await addScript('나');
    await sessions.add(session(a.id!, DateTime(2026, 1, 1)));
    await sessions.add(session(b.id!, DateTime(2026, 3, 1)));
    await sessions.add(session(a.id!, DateTime(2026, 2, 1)));
    final all = await sessions.all();
    expect(all.map((s) => s.createdAt.month), [3, 2, 1]);
  });

  test('v4 DB를 v5로 열어도 원고가 남고 폴더 없음이 된다', () async {
    final dir = Directory.systemTemp.createTempSync('v5_upgrade');
    final path = p.join(dir.path, 'up.db');
    final v4 = await openAppDatabase(path, factory: databaseFactoryFfi, version: 4);
    await v4.insert('scripts', {'title': 't', 'body': '본문', 'is_premium': 0, 'created_at': 0});
    await v4.close();
    final v5 = await openAppDatabase(path, factory: databaseFactoryFfi);
    final s = (await ScriptRepository(v5, SessionRepository(v5)).all()).single;
    expect(s.body, '본문');
    expect(s.folderId, isNull);
    expect(await FolderRepository(v5).all(), isEmpty);
    await v5.close();
    dir.deleteSync(recursive: true);
  });

  group('기본 폴더 (경제·시사·연예·스포츠)', () {
    test('기본 폴더 이름 목록', () {
      expect(defaultFolderNames, ['경제', '시사', '연예', '스포츠']);
      expect(isDefaultFolder(Folder(name: '경제', createdAt: DateTime(2026))), isTrue);
      expect(isDefaultFolder(Folder(name: '내 폴더', createdAt: DateTime(2026))), isFalse);
    });

    test('기본 폴더는 이름을 바꿀 수 없다', () async {
      final id = await folders.add('경제');
      expect(() => folders.rename(id, '돈 이야기'), throwsArgumentError);
      expect((await folders.all()).single.name, '경제');
    });

    test('기본 폴더는 지울 수 없고 안의 원고도 그대로', () async {
      final id = await folders.add('스포츠');
      final s = await addScript('야구', folderId: id);
      expect(() => folders.delete(id), throwsArgumentError);
      expect(await folders.all(), hasLength(1));
      expect((await scripts.all()).firstWhere((x) => x.id == s.id).folderId, id);
    });

    test('다른 폴더는 지금처럼 바꾸고 지울 수 있다', () async {
      final id = await folders.add('내 폴더');
      await folders.rename(id, '내 원고');
      await folders.delete(id);
      expect(await folders.all(), isEmpty);
    });
  });
}
