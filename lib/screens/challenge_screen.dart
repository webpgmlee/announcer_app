import 'package:app_settings/app_settings.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/diction_score.dart';
import '../analysis/error_stats.dart';
import '../analysis/script_layout.dart';
import '../data/models.dart';
import '../practice/practice_controller.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/prompter.dart';
import '../widgets/studio.dart';
import 'challenge_result_view.dart';

/// 퍼펙트딕션 도전: 정해진 속도로 노래방식 진행 → 자동 정지 → 딕션 점수.
/// 녹음관리 기록은 만들지 않고 점수만 저장한다.
class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.challengeKey,
    required this.title,
    required this.body,
    required this.pace,
  });

  final String challengeKey;
  final String title;
  final String body;
  final double pace;

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen> {
  late final PracticeController _c;
  late final List<String> _words = scriptWords(widget.body);
  late final Map<int, Pause> _pauses = autoPauses(_words);
  DictionScore? _score;
  bool _newBest = false;
  PracticePhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    _c = PracticeController(
      script: Script(
        title: widget.title,
        body: widget.body,
        createdAt: DateTime.now(),
      ),
      recorder: ref.read(recorderProvider),
      transcriber: ref.read(transcriberProvider),
      sessions: ref.read(sessionRepositoryProvider),
      pace: widget.pace,
      keepRecording: false,
    );
    _c.addListener(_onChange);
  }

  void _onChange() {
    final s = _c.state;
    if (s.phase == PracticePhase.permissionDenied && _lastPhase != s.phase) {
      _showPermissionGuide();
    }
    _lastPhase = s.phase;
    if (s.phase == PracticePhase.result &&
        s.resultStatus == ResultStatus.complete &&
        _score == null &&
        s.error == null) {
      _finish(s);
    }
    setState(() {});
  }

  /// 인식이 끝나면 한 번만 점수를 매기고 저장한다.
  Future<void> _finish(PracticeState s) async {
    final score = ref
        .read(dictionScorerProvider)
        .score(
          script: widget.body,
          transcript: s.transcript ?? '',
          voiced: s.voiced ?? Duration.zero,
          targetPace: widget.pace,
        );
    _score = score;
    final repo = ref.read(challengeRepositoryProvider);
    final before = (await repo.best())[widget.challengeKey]?.score;
    await repo.add(widget.challengeKey, score);
    ref.invalidate(challengeBestProvider);
    if (mounted) {
      setState(
        () => _newBest =
            score.total > 0 && (before == null || score.total > before),
      );
    }
  }

  void _retry() {
    _score = null;
    _newBest = false;
    _c.reset();
  }

  Future<void> _showPermissionGuide() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('마이크를 쓸 수 없어요'),
      content: const Text('도전을 녹음하려면 설정에서 이 앱의 마이크 권한을 켜 주세요.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            AppSettings.openAppSettings();
          },
          child: const Text('설정 열기'),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _c.state;
    final recording = s.phase == PracticePhase.recording;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '목표 ${widget.pace.round()}음절/분',
                    style: const TextStyle(fontSize: 16, color: Palette.muted),
                  ),
                  const Spacer(),
                  OnAirBadge(active: recording),
                ],
              ),
              Expanded(child: _content(s, recording)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(PracticeState s, bool recording) {
    if (s.phase == PracticePhase.result) {
      final score = _score;
      if (s.error != null) {
        return _CenterMessage(
          text: '점수를 계산하지 못했어요. 다시 도전해 주세요.',
          action: '다시 도전',
          onAction: _retry,
        );
      }
      if (score == null) {
        return const _CenterMessage(text: '점수를 계산하는 중이에요', loading: true);
      }
      return ChallengeResultView(
        score: score,
        targetPace: widget.pace,
        marks: s.marks,
        newBest: _newBest,
        message: s.message,
        onRetry: _retry,
        onExit: () => Navigator.of(context).pop(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Prompter(
                  words: _words,
                  pauses: _pauses,
                  memos: const {},
                  stats: const WordErrorStats(recognized: 0, wrong: {}),
                  currentSentence: s.sentence,
                  karaoke: recording && s.karaoke,
                  activeWord: s.word,
                  wordFill: s.wordFill,
                ),
              ),
              if (recording && s.countdown != null)
                CountdownBadge(value: s.countdown!),
              if (recording)
                Positioned(top: 4, child: PaceBadge(feedback: s.paceFeedback)),
            ],
          ),
        ),
        ScriptProgressBar(progress: s.progress),
        const SizedBox(height: 14),
        TapeControls(
          recording: recording,
          onPressed: () => recording ? _c.stop() : _c.start(),
        ),
      ],
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({
    required this.text,
    this.loading = false,
    this.action,
    this.onAction,
  });
  final String text;
  final bool loading;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(text, style: const TextStyle(fontSize: 16, color: Palette.muted)),
        if (action != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(action!)),
        ],
      ],
    ),
  );
}
