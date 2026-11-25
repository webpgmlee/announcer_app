import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/default_scripts.dart';
import 'data/memo_repository.dart';
import 'data/script_repository.dart';
import 'data/session_repository.dart';
import 'data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase(p.join(await getDatabasesPath(), 'announcer.db'));
  final sessions = SessionRepository(db);
  final scripts = ScriptRepository(db, sessions);
  // 처음 설치했을 때(또는 이 버전으로 처음 올렸을 때) 기본 연습 원고를 한 번 넣는다.
  await seedDefaultScripts(db, scripts);
  runApp(ProviderScope(
    overrides: [
      sessionRepositoryProvider.overrideWithValue(sessions),
      scriptRepositoryProvider.overrideWithValue(scripts),
      memoRepositoryProvider.overrideWithValue(MemoRepository(db)),
      settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
    ],
    child: const AnnouncerApp(),
  ));
}
