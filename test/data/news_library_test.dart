import 'package:announcer_app/analysis/read_aloud.dart';
import 'package:announcer_app/data/database.dart';
import 'package:announcer_app/data/folder_repository.dart';
import 'package:announcer_app/data/news_library.dart';
import 'package:announcer_app/data/script_repository.dart';
import 'package:announcer_app/data/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late ScriptRepository scripts;
  late FolderRepository folders;

  setUp(() async {
    db = await openAppDatabase(inMemoryDatabasePath, factory: databaseFactoryFfi);
    scripts = ScriptRepository(db, SessionRepository(db));
    folders = FolderRepository(db);
  });
  tearDown(() => db.close());

  group('원고 묶음 내용', () {
    test('4개 분야 × 초·중·고급 × 3개 = 36개', () {
      expect(newsLibrary, hasLength(36));
      for (final c in newsCategories) {
        for (final level in [1, 2, 3]) {
          expect(newsLibrary.where((n) => n.category == c && n.level == level), hasLength(3),
              reason: '$c $level');
        }
      }
      expect(newsCategories, ['경제', '시사', '연예', '스포츠']);
    });

    test('제목은 겹치지 않고 난이도 표시로 시작한다', () {
      expect(newsLibrary.map((n) => n.title).toSet(), hasLength(36));
      for (final n in newsLibrary) {
        expect(n.title, startsWith('${levelLabels[n.level]} · '));
      }
    });

    test('난이도가 올라갈수록 원고가 길다 (분야별 평균 음절)', () {
      for (final c in newsCategories) {
        double avg(int level) {
          final xs = newsLibrary.where((n) => n.category == c && n.level == level);
          return xs.map((n) => readAloud(n.body).length).reduce((a, b) => a + b) / xs.length;
        }

        expect(avg(1), lessThan(avg(2)), reason: c);
        expect(avg(2), lessThan(avg(3)), reason: c);
      }
    });

    test('모든 문장은 마침표로 끝나고, 과장 문구가 없다', () {
      for (final n in newsLibrary) {
        expect(n.body.trim(), endsWith('.'), reason: n.title);
        expect(n.body, isNot(contains('발음 점수')));
        expect(n.body, isNot(contains('발음 채점')));
      }
    });

    test('읽는 소리로 바꾸면 영어 알파벳이 남지 않는다 (숫자·약어 모두 읽힘)', () {
      for (final n in newsLibrary) {
        expect(RegExp('[A-Za-z]').hasMatch(readAloud(n.body)), isFalse, reason: n.title);
      }
    });
  });

  group('앱에 넣기', () {
    test('분야별 폴더를 만들고 난이도와 함께 넣는다', () async {
      await seedNewsLibrary(db, scripts, folders);
      final fs = await folders.all();
      expect(fs.map((f) => f.name), ['경제', '시사', '연예', '스포츠']);
      final all = await scripts.all();
      expect(all, hasLength(36));
      for (final f in fs) {
        final inFolder = all.where((s) => s.folderId == f.id).toList();
        expect(inFolder, hasLength(9));
        expect(inFolder.map((s) => s.category).toSet(), {f.name});
        expect(inFolder.map((s) => s.difficulty).toList()..sort(), [1, 1, 1, 2, 2, 2, 3, 3, 3]);
      }
    });

    test('목록(최신순)에서는 경제 초급이 맨 위에 온다', () async {
      await seedNewsLibrary(db, scripts, folders);
      expect((await scripts.all()).first.title, newsLibrary.first.title);
    });

    test('두 번 넣어도 한 번만 들어간다', () async {
      await seedNewsLibrary(db, scripts, folders);
      await seedNewsLibrary(db, scripts, folders);
      expect(await scripts.all(), hasLength(36));
      expect(await folders.all(), hasLength(4));
    });

    test('같은 이름의 폴더가 이미 있으면 그 폴더에 넣는다', () async {
      final mine = await folders.add('경제');
      await seedNewsLibrary(db, scripts, folders);
      expect(await folders.all(), hasLength(4));
      final econ = (await scripts.all()).where((s) => s.category == '경제');
      expect(econ.every((s) => s.folderId == mine), isTrue);
    });

    test('사용자가 지운 원고는 다시 넣지 않는다', () async {
      await seedNewsLibrary(db, scripts, folders);
      final first = (await scripts.all()).first;
      await scripts.delete(first.id!);
      await seedNewsLibrary(db, scripts, folders);
      expect(await scripts.all(), hasLength(35));
    });
  });
}
