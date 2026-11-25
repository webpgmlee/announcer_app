import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../analysis/script_layout.dart';
import 'memo_repository.dart';
import 'models.dart';
import 'session_repository.dart';

class ScriptRepository {
  ScriptRepository(this._db, this._sessions);
  final Database _db;
  final SessionRepository _sessions;

  /// 원고를 저장한다. 본문이 비어 있거나 공백뿐이면 [ArgumentError].
  Future<int> add(Script s) async {
    if (s.body.trim().isEmpty) {
      throw ArgumentError.value(s.body, 'body', '원고 본문이 비어 있어요');
    }
    return _db.insert('scripts', {
      'title': s.title,
      'body': s.body,
      'category': s.category,
      'difficulty': s.difficulty,
      'is_premium': s.isPremium ? 1 : 0,
      'folder_id': s.folderId,
      'created_at': s.createdAt.millisecondsSinceEpoch,
    });
  }

  /// 최근에 추가한 원고부터.
  Future<List<Script>> all() async {
    final rows =
        await _db.query('scripts', orderBy: 'created_at DESC, id DESC');
    return rows
        .map((r) => Script(
              id: r['id'] as int,
              title: r['title'] as String,
              body: r['body'] as String,
              category: r['category'] as String?,
              difficulty: r['difficulty'] as int?,
              isPremium: r['is_premium'] == 1,
              folderId: r['folder_id'] as int?,
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
            ))
        .toList();
  }

  /// 원고와 그 연습 기록, 오디오 파일, 메모를 함께 지운다.
  Future<void> delete(int id) async {
    await _sessions.deleteForScript(id);
    await MemoRepository(_db).deleteForScript(id);
    await _db.delete('scripts', where: 'id = ?', whereArgs: [id]);
  }

  /// 원고의 끊어 읽기 표시. 아직 없으면(예전 원고, 새 원고) 문장부호로 만들어 저장한다.
  Future<Map<int, Pause>> pauses(Script s) async {
    final rows = await _db.query('scripts',
        columns: ['pause_json'], where: 'id = ?', whereArgs: [s.id]);
    final json = rows.isEmpty ? null : rows.single['pause_json'] as String?;
    if (json != null) {
      return {
        for (final e in (jsonDecode(json) as Map<String, dynamic>).entries)
          int.parse(e.key): Pause.values.byName(e.value as String),
      };
    }
    final auto = autoPauses(scriptWords(s.body));
    await setPauses(s.id!, auto);
    return auto;
  }

  Future<void> setPauses(int scriptId, Map<int, Pause> pauses) => _db.update(
        'scripts',
        {
          'pause_json': jsonEncode({
            for (final e in pauses.entries)
              if (e.value != Pause.none) '${e.key}': e.value.name,
          }),
        },
        where: 'id = ?',
        whereArgs: [scriptId],
      );

  /// 원고를 다른 폴더로 옮긴다. [folderId]가 null이면 폴더 없음.
  Future<void> moveToFolder(int scriptId, int? folderId) => _db.update(
      'scripts', {'folder_id': folderId},
      where: 'id = ?', whereArgs: [scriptId]);

  /// 원고를 복제한다. 제목 뒤에 "(복사본)"을 붙이고 끊어 읽기 표시와 메모를 복사한다.
  /// 녹음 기록은 복사하지 않는다. 새 원고 번호를 돌려준다.
  Future<int> duplicate(Script s) async {
    final pauseMarks = await pauses(s);
    final id = await add(Script(
      title: '${s.title} (복사본)',
      body: s.body,
      category: s.category,
      difficulty: s.difficulty,
      isPremium: s.isPremium,
      folderId: s.folderId,
      createdAt: DateTime.now(),
    ));
    await setPauses(id, pauseMarks);
    final memos = MemoRepository(_db);
    for (final m in (await memos.forScript(s.id!)).values) {
      await memos.save(Memo(
        scriptId: id,
        wordIndex: m.wordIndex,
        kind: m.kind,
        text: m.text,
        createdAt: m.createdAt,
      ));
    }
    return id;
  }
}
