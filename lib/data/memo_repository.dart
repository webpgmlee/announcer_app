import 'package:sqflite/sqflite.dart';

import 'models.dart';

class MemoRepository {
  MemoRepository(this._db);
  final Database _db;

  /// 원고의 메모. 어절 번호 → 메모.
  Future<Map<int, Memo>> forScript(int scriptId) async {
    final rows = await _db.query('memos', where: 'script_id = ?', whereArgs: [scriptId]);
    return {
      for (final r in rows)
        r['word_index'] as int: Memo(
          id: r['id'] as int,
          scriptId: r['script_id'] as int,
          wordIndex: r['word_index'] as int,
          kind: MemoKind.values.byName(r['kind'] as String),
          text: r['text'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        ),
    };
  }

  /// 메모를 저장한다. 같은 어절의 메모는 바꾸고, 글이 비어 있으면 지운다.
  Future<void> save(Memo m) async {
    if (m.text.trim().isEmpty) {
      await _db.delete('memos',
          where: 'script_id = ? AND word_index = ?', whereArgs: [m.scriptId, m.wordIndex]);
      return;
    }
    await _db.insert(
      'memos',
      {
        'script_id': m.scriptId,
        'word_index': m.wordIndex,
        'kind': m.kind.name,
        'text': m.text.trim(),
        'created_at': m.createdAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteForScript(int scriptId) =>
      _db.delete('memos', where: 'script_id = ?', whereArgs: [scriptId]);
}
