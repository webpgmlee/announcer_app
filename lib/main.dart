import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/memo_repository.dart';
import 'data/script_repository.dart';
import 'data/session_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase(p.join(await getDatabasesPath(), 'announcer.db'));
  final sessions = SessionRepository(db);
  runApp(ProviderScope(
    overrides: [
      sessionRepositoryProvider.overrideWithValue(sessions),
      scriptRepositoryProvider.overrideWithValue(ScriptRepository(db, sessions)),
      memoRepositoryProvider.overrideWithValue(MemoRepository(db)),
    ],
    child: const AnnouncerApp(),
  ));
}
