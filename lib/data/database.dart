import 'package:sqflite/sqflite.dart';

/// 현재 DB 스키마 버전. 올릴 때는 [_migrations]에 단계를 추가만 한다.
/// 테이블을 지우거나 다시 만들지 않는다 (기록 보존, 스펙 4장).
const currentSchemaVersion = 3;

/// _migrations[i]는 버전 i+1로 올리는 단계다.
final List<Future<void> Function(Database db)> _migrations = [
  // v1: 원고와 연습 기록
  (db) async {
    await db.execute('''
      CREATE TABLE scripts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        category TEXT,
        difficulty INTEGER,
        is_premium INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        script_id INTEGER NOT NULL REFERENCES scripts(id),
        audio_path TEXT NOT NULL,
        elapsed_ms INTEGER NOT NULL,
        spm REAL NOT NULL,
        pitch_json TEXT NOT NULL,
        marks_json TEXT,
        created_at INTEGER NOT NULL
      )''');
    await db.execute('CREATE INDEX sessions_script ON sessions(script_id)');
  },
  // v2: 인식된 글 저장
  (db) async {
    await db.execute('ALTER TABLE sessions ADD COLUMN transcript TEXT');
  },
  // v3: 끊어 읽기 표시와 어절 메모
  (db) async {
    await db.execute('ALTER TABLE scripts ADD COLUMN pause_json TEXT');
    await db.execute('''
      CREATE TABLE memos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        script_id INTEGER NOT NULL REFERENCES scripts(id),
        word_index INTEGER NOT NULL,
        kind TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE (script_id, word_index)
      )''');
  },
];

Future<Database> openAppDatabase(
  String path, {
  DatabaseFactory? factory,
  int version = currentSchemaVersion,
}) {
  Future<void> migrate(Database db, int from, int to) async {
    for (var v = from; v < to; v++) {
      await _migrations[v](db);
    }
  }

  return (factory ?? databaseFactory).openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: version,
      onCreate: (db, v) => migrate(db, 0, v),
      onUpgrade: (db, from, to) => migrate(db, from, to),
    ),
  );
}
