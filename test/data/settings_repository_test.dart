import 'dart:io';

import 'package:announcer_app/data/database.dart';
import 'package:announcer_app/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  setUp(() async =>
      db = await openAppDatabase(inMemoryDatabasePath, factory: databaseFactoryFfi));
  tearDown(() => db.close());

  test('스키마 버전은 4', () async {
    expect(currentSchemaVersion, 4);
    expect(await db.getVersion(), 4);
  });

  test('저장한 적이 없으면 기본 350', () async {
    expect(await SettingsRepository(db).pace(), 350);
  });

  test('속도를 저장하면 다시 읽어도 같다', () async {
    await SettingsRepository(db).setPace(380);
    expect(await SettingsRepository(db).pace(), 380);
  });

  test('범위 밖이거나 깨진 값은 범위로 맞춘다 (Review Focus 4)', () async {
    await db.insert('settings', {'key': 'pace', 'value': '9999'});
    expect(await SettingsRepository(db).pace(), 500);
    await db.update('settings', {'value': '엉망'}, where: 'key = ?', whereArgs: ['pace']);
    expect(await SettingsRepository(db).pace(), 350);
  });

  test('v3 DB를 v4로 열어도 원고가 남는다', () async {
    final dir = Directory.systemTemp.createTempSync('v4_upgrade');
    final path = p.join(dir.path, 'up.db');
    final v3 = await openAppDatabase(path, factory: databaseFactoryFfi, version: 3);
    await v3.insert('scripts',
        {'title': 't', 'body': '본문', 'is_premium': 0, 'created_at': 0, 'pause_json': '{}'});
    await v3.close();
    final v4 = await openAppDatabase(path, factory: databaseFactoryFfi);
    expect((await v4.query('scripts')).single['body'], '본문');
    expect(await SettingsRepository(v4).pace(), 350);
    await v4.close();
    dir.deleteSync(recursive: true);
  });
}
