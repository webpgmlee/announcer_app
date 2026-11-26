import 'dart:io';

import 'package:announcer_app/analysis/diction_score.dart';
import 'package:announcer_app/data/challenge_repository.dart';
import 'package:announcer_app/data/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DictionScore score(int total) => DictionScore(
      total: total,
      accuracy: total.toDouble(),
      speed: total.toDouble(),
      measuredPace: 300,
      stars: starsFor(total),
      perfect: total == 100,
    );

void main() {
  sqfliteFfiInit();
  late Database db;
  late ChallengeRepository repo;
  setUp(() async {
    db = await openAppDatabase(inMemoryDatabasePath, factory: databaseFactoryFfi);
    repo = ChallengeRepository(db);
  });
  tearDown(() => db.close());

  test('스키마 버전은 7', () async {
    expect(currentSchemaVersion, 7);
    expect(await db.getVersion(), 7);
  });

  test('도전 키 만들기', () {
    expect(twisterKey('ganjang'), 'twister:ganjang');
    expect(scriptKey(12), 'script:12');
  });

  test('도전마다 최고 점수와 별을 돌려준다', () async {
    await repo.add('twister:ganjang', score(72));
    await repo.add('twister:ganjang', score(96));
    await repo.add('script:3', score(88));
    final best = await repo.best();
    expect(best['twister:ganjang'], (score: 96, stars: 3));
    expect(best['script:3'], (score: 88, stars: 2));
    expect(best.containsKey('twister:girin'), isFalse);
  });

  test('낮은 점수가 나중에 와도 최고 점수는 그대로 (Review Focus 5)', () async {
    await repo.add('twister:ganjang', score(96));
    await repo.add('twister:ganjang', score(40));
    expect((await repo.best())['twister:ganjang']!.score, 96);
  });

  test('v6 DB를 v7로 열어도 원고가 남는다', () async {
    final dir = Directory.systemTemp.createTempSync('v7_upgrade');
    final path = p.join(dir.path, 'up.db');
    final v6 = await openAppDatabase(path, factory: databaseFactoryFfi, version: 6);
    await v6.insert('scripts', {'title': 't', 'body': '본문', 'is_premium': 0, 'created_at': 0});
    await v6.close();
    final v7 = await openAppDatabase(path, factory: databaseFactoryFfi);
    expect((await v7.query('scripts')).single['body'], '본문');
    expect(await ChallengeRepository(v7).best(), isEmpty);
    await v7.close();
    dir.deleteSync(recursive: true);
  });
}
