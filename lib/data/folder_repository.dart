import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// 앱이 기본 뉴스 원고를 넣으며 만드는 폴더. 이름을 바꾸거나 지울 수 없다.
const defaultFolderNames = ['경제', '시사', '연예', '스포츠'];

bool isDefaultFolder(Folder f) => defaultFolderNames.contains(f.name);

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

  /// 이름을 바꾼다. 규칙은 [add]와 같다 (자기 이름 그대로는 괜찮다). 기본 폴더는 바꿀 수 없다.
  Future<void> rename(int id, String name) async {
    await _refuseDefault(id);
    final n = await _checkName(name, except: id);
    await _db.update('folders', {'name': n}, where: 'id = ?', whereArgs: [id]);
  }

  /// 폴더를 지운다. 안의 원고는 지우지 않고 폴더 없음으로 옮긴다. 기본 폴더는 지울 수 없다.
  Future<void> delete(int id) async {
    await _refuseDefault(id);
    await _db.update('scripts', {'folder_id': null}, where: 'folder_id = ?', whereArgs: [id]);
    await _db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _refuseDefault(int id) async {
    final rows = await _db.query('folders', columns: ['name'], where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty && defaultFolderNames.contains(rows.single['name'])) {
      throw ArgumentError.value(id, 'id', '기본 폴더는 바꾸거나 지울 수 없어요');
    }
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
