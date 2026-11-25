import 'package:announcer_app/analysis/read_aloud.dart';
import 'package:announcer_app/data/database.dart';
import 'package:announcer_app/data/default_scripts.dart';
import 'package:announcer_app/data/script_repository.dart';
import 'package:announcer_app/data/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late ScriptRepository scripts;

  setUp(() async {
    db = await openAppDatabase(inMemoryDatabasePath, factory: databaseFactoryFfi);
    scripts = ScriptRepository(db, SessionRepository(db));
  });
  tearDown(() => db.close());

  test('처음 실행하면 기본 원고(폭우 피해 뉴스)가 들어간다', () async {
    await seedDefaultScripts(db, scripts);
    final all = await scripts.all();
    expect(all, hasLength(1));
    expect(all.single.title, '기상이변으로 인한 폭우 피해');
    expect(all.single.category, '뉴스');
    expect(all.single.isPremium, isFalse);
    expect(all.single.body, startsWith('올해 여름, 전국적으로 기록적인 폭우가'));
    expect(all.single.body, endsWith('추가 지원 대책을 논의할 예정입니다.'));
    expect(all.single.body.split('\n'), hasLength(9));
  });

  test('두 번 실행해도 한 번만 들어간다', () async {
    await seedDefaultScripts(db, scripts);
    await seedDefaultScripts(db, scripts);
    expect(await scripts.all(), hasLength(1));
  });

  test('사용자가 지우면 다시 넣지 않는다', () async {
    await seedDefaultScripts(db, scripts);
    await scripts.delete((await scripts.all()).single.id!);
    await seedDefaultScripts(db, scripts);
    expect(await scripts.all(), isEmpty);
  });

  test('원고의 100mm는 백밀리미터로 읽는다', () {
    expect(readAloud('시간당 100mm 이상'), '시간당 백밀리미터 이상');
  });
}
