import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analysis/diction_score.dart';
import 'analysis/error_stats.dart';
import 'analysis/script_layout.dart';
import 'audio/player.dart';
import 'audio/recorder.dart';
import 'data/challenge_repository.dart';
import 'data/folder_repository.dart';
import 'data/memo_repository.dart';
import 'data/models.dart';
import 'data/practice_state.dart';
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
final folderRepositoryProvider =
    Provider<FolderRepository>((ref) => throw UnimplementedError());
final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => throw UnimplementedError());

final scriptsProvider = FutureProvider<List<Script>>(
    (ref) => ref.watch(scriptRepositoryProvider).all());
final foldersProvider = FutureProvider<List<Folder>>(
    (ref) => ref.watch(folderRepositoryProvider).all());

/// 모든 원고의 녹음 기록 (녹음관리).
final allSessionsProvider = FutureProvider<List<PracticeSession>>(
    (ref) => ref.watch(sessionRepositoryProvider).all());

/// 원고별 녹음 횟수와 마지막 연습 시각 (연습 중 판단, 카드 표시).
final practiceStatsProvider = FutureProvider<Map<int, PracticeStat>>(
    (ref) => ref.watch(sessionRepositoryProvider).practiceStats());

/// 원고 하나의 녹음 기록 (원고 조회의 녹음 횟수 등).
final sessionsForScriptProvider = FutureProvider.family<List<PracticeSession>, int>(
    (ref, scriptId) => ref.watch(sessionRepositoryProvider).forScript(scriptId));

/// 원고·녹음이 바뀐 뒤 목록들을 다시 읽게 한다.
void refreshLists(WidgetRef ref) {
  ref.invalidate(scriptsProvider);
  ref.invalidate(foldersProvider);
  ref.invalidate(allSessionsProvider);
  ref.invalidate(practiceStatsProvider);
  ref.invalidate(sessionsForScriptProvider);
}

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
final playerFactoryProvider =
    Provider<Player Function()>((ref) => JustAudioPlayer.new);

/// 퍼펙트딕션: 도전 기록, 도전마다 최고 점수·별, 점수 계산기(나중에 클라우드 평가로 바꿔 끼움).
final challengeRepositoryProvider =
    Provider<ChallengeRepository>((ref) => throw UnimplementedError());
final challengeBestProvider = FutureProvider<Map<String, ChallengeBest>>(
    (ref) => ref.watch(challengeRepositoryProvider).best());
final dictionScorerProvider = Provider<DictionScorer>((ref) => const OnDeviceDictionScorer());
