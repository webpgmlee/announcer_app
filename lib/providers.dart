import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analysis/error_stats.dart';
import 'analysis/script_layout.dart';
import 'audio/player.dart';
import 'data/memo_repository.dart';
import 'audio/recorder.dart';
import 'data/models.dart';
import 'data/script_repository.dart';
import 'data/session_repository.dart';
import 'data/settings_repository.dart';
import 'speech/transcriber.dart';
import 'speech/whisper_transcriber.dart';

/// main()에서 DB를 연 뒤 ProviderScope overrides로 넣는다.
final scriptRepositoryProvider =
    Provider<ScriptRepository>((ref) => throw UnimplementedError());
final sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => throw UnimplementedError());

final memoRepositoryProvider =
    Provider<MemoRepository>((ref) => throw UnimplementedError());

final scriptsProvider = FutureProvider<List<Script>>(
    (ref) => ref.watch(scriptRepositoryProvider).all());

/// 녹음·기록 탭에서 쓰는 "지금 원고".
class CurrentScript extends Notifier<Script?> {
  @override
  Script? build() => null;
  void select(Script? s) => state = s;
}

final currentScriptProvider = NotifierProvider<CurrentScript, Script?>(CurrentScript.new);

/// 아래 탭: 0 대본, 1 녹음, 2 기록.
class HomeTab extends Notifier<int> {
  @override
  int build() => 0;
  void go(int tab) => state = tab;
}

final homeTabProvider = NotifierProvider<HomeTab, int>(HomeTab.new);

/// 원고 위에 그릴 것들: 어절, 끊어 읽기 표시, 메모, 자주 틀림.
class ScriptDetails {
  const ScriptDetails({
    required this.words,
    required this.pauses,
    required this.memos,
    required this.stats,
  });
  final List<String> words;
  final Map<int, Pause> pauses;
  final Map<int, Memo> memos;
  final WordErrorStats stats;
}

final scriptDetailsProvider =
    FutureProvider.family<ScriptDetails, Script>((ref, script) async {
  final pauses = await ref.watch(scriptRepositoryProvider).pauses(script);
  final memos = await ref.watch(memoRepositoryProvider).forScript(script.id!);
  final sessions = await ref.watch(sessionRepositoryProvider).forScript(script.id!);
  return ScriptDetails(
    words: scriptWords(script.body),
    pauses: pauses,
    memos: memos,
    stats: errorStats(sessions.map((s) => s.marks)),
  );
});

final recorderProvider =
    Provider<Recorder>((ref) => StreamRecorder(RecordPcmSource()));
final transcriberProvider = Provider<Transcriber>((ref) => WhisperTranscriber());
final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => throw UnimplementedError());
final playerFactoryProvider =
    Provider<Player Function()>((ref) => JustAudioPlayer.new);
