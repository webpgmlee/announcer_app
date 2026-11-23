import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/models.dart';
import 'data/script_repository.dart';
import 'data/session_repository.dart';

/// main()에서 DB를 연 뒤 ProviderScope overrides로 넣는다.
final scriptRepositoryProvider =
    Provider<ScriptRepository>((ref) => throw UnimplementedError());
final sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => throw UnimplementedError());

final scriptsProvider = FutureProvider<List<Script>>(
    (ref) => ref.watch(scriptRepositoryProvider).all());
