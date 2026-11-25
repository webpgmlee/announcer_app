import 'package:sqflite/sqflite.dart';

import '../analysis/karaoke.dart';

/// 앱 설정. 지금은 노래방식 진행 속도(1분당 음절)만 있다.
class SettingsRepository {
  SettingsRepository(this._db);
  final Database _db;

  static const _paceKey = 'pace';

  /// 저장된 속도. 없거나 깨졌으면 기본 350, 범위 밖이면 범위로 맞춘다.
  Future<double> pace() async {
    final rows = await _db.query('settings',
        columns: ['value'], where: 'key = ?', whereArgs: [_paceKey]);
    final v = rows.isEmpty ? null : double.tryParse(rows.single['value'] as String);
    return v == null ? defaultPace : clampPace(v);
  }

  Future<void> setPace(double pace) => _db.insert(
        'settings',
        {'key': _paceKey, 'value': clampPace(pace).toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
