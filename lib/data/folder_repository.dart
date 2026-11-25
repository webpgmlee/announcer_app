import 'package:sqflite/sqflite.dart';

import 'models.dart';

class FolderRepository {
  FolderRepository(this._db);
  final Database _db;

  /// 만든 순서대로.
  Future<List<Folder>> all() async {
    final rows = await _db.query('folders', orderBy: 'created_at, id');
    return [
      for (final r in rows)
        Folder(
          id: r['id'] as int,
          name: r['name'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        ),
    ];
  }

  /// 폴더를 만든다. 이름이 비었거나 다른 폴더와 같으면 [ArgumentError].
  Future<int> add(String name) async {
    final n = await _checkName(name);
    return _db.insert('folders', {'name': n, 'created_at': DateTime.now().millisecondsSinceEpoch});
  }

  /// 이름을 바꾼다. 규칙은 [add]와 같다 (자기 이름 그대로는 괜찮다).
  Future<void> rename(int id, String name) async {
    final n = await _checkName(name, except: id);
    await _db.update('folders', {'name': n}, where: 'id = ?', whereArgs: [id]);
  }

  /// 폴더를 지운다. 안의 원고는 지우지 않고 폴더 없음으로 옮긴다.
  Future<void> delete(int id) async {
    await _db.update('scripts', {'folder_id': null}, where: 'folder_id = ?', whereArgs: [id]);
    await _db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> _checkName(String name, {int? except}) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError.value(name, 'name', '폴더 이름을 입력해 주세요');
    final same = await _db.query('folders',
        columns: ['id'],
        where: except == null ? 'name = ?' : 'name = ? AND id != ?',
        whereArgs: except == null ? [n] : [n, except]);
    if (same.isNotEmpty) throw ArgumentError.value(name, 'name', '같은 이름의 폴더가 있어요');
    return n;
  }
}
