import 'package:sqflite/sqflite.dart';

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
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
            ))
        .toList();
  }

  /// 원고와 그 연습 기록, 오디오 파일을 함께 지운다.
  Future<void> delete(int id) async {
    await _sessions.deleteForScript(id);
    await _db.delete('scripts', where: 'id = ?', whereArgs: [id]);
  }
}
