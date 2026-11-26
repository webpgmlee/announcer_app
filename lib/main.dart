import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'data/challenge_repository.dart';
import 'data/database.dart';
import 'data/default_scripts.dart';
import 'data/folder_repository.dart';
import 'data/memo_repository.dart';
import 'data/news_library.dart';
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
  // 분야별(경제·시사·연예·스포츠) 초·중·고급 뉴스 연습 원고 36개도 한 번 넣는다.
  final folders = FolderRepository(db);
  await seedNewsLibrary(db, scripts, folders);
  runApp(ProviderScope(
    overrides: [
      sessionRepositoryProvider.overrideWithValue(sessions),
      scriptRepositoryProvider.overrideWithValue(scripts),
      memoRepositoryProvider.overrideWithValue(MemoRepository(db)),
      folderRepositoryProvider.overrideWithValue(folders),
      settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
      challengeRepositoryProvider.overrideWithValue(ChallengeRepository(db)),
    ],
    child: const AnnouncerApp(),
  ));
}
