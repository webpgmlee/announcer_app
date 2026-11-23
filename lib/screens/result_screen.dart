import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/compare.dart';
import '../analysis/intonation.dart';
import '../audio/player.dart';
import '../data/models.dart';
import '../practice/practice_controller.dart';
import '../providers.dart';
import '../widgets/marked_script.dart';
import '../widgets/pitch_line.dart';

String formatDuration(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// 지난 연습 기록 하나의 결과 화면 (기록 화면에서 연다).
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.script, required this.session});
  final Script script;
  final PracticeSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(script.title)),
        body: ResultView(
          script: script,
          session: session,
          intonation: analyzeIntonation(session.pitch),
          status: ResultStatus.complete,
          marks: session.marks,
          error: session.marks == null ? '이 기록에는 원고 비교 결과가 없어요' : null,
          playerFactory: ref.read(playerFactoryProvider),
        ),
      );
}

/// 결과 내용. 연습 직후(연습 화면)와 기록 보기(결과 화면)에서 같이 쓴다.
class ResultView extends StatefulWidget {
  const ResultView({
    super.key,
    required this.script,
    this.session,
    this.intonation,
    required this.status,
    this.marks,
    this.progress = 0,
    this.message,
    this.error,
    this.interrupted = false,
    this.onRetry,
    this.playerFactory,
  });

  final Script script;
  final PracticeSession? session;
  final IntonationReport? intonation;
  final ResultStatus status;
  final List<WordMark>? marks;
  final double progress;
  final String? message;
  final String? error;
  final bool interrupted;
  final VoidCallback? onRetry;
  final Player Function()? playerFactory;

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  Player? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;
  Duration? _position;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    if (widget.playerFactory != null && widget.session != null) {
      final player = _player = widget.playerFactory!();
      _posSub = player.position.listen((p) => setState(() => _position = p));
      _playSub = player.playing.listen((v) => setState(() => _playing = v));
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _playSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null) return;
    if (_playing) {
      await player.pause();
    } else {
      try {
        await player.play(widget.session!.audioPath);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('녹음 파일을 재생하지 못했어요')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.message != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.mic_off_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(widget.message!, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('마이크 가까이에서 소리 내어 읽어 주세요.'),
            const SizedBox(height: 24),
            if (widget.onRetry != null)
              FilledButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 연습'),
              ),
          ]),
        ),
      );
    }

    final s = widget.session;
    final report = widget.intonation;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (widget.interrupted)
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('녹음이 중간에 끊겨서 그때까지 저장했어요'),
            ),
          ),
        if (s != null) ...[
          Row(children: [
            Expanded(child: _Metric(label: '걸린 시간', value: formatDuration(s.elapsed))),
            const SizedBox(width: 12),
            Expanded(
                child: _Metric(
                    label: '1분당 음절',
                    value: s.syllablesPerMinute.round().toString())),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Text('억양', style: theme.textTheme.titleMedium),
            const Spacer(),
            if (_player != null)
              IconButton.filledTonal(
                onPressed: _togglePlay,
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                tooltip: _playing ? '멈춤' : '다시 듣기',
              ),
          ]),
          PitchLine(pitch: s.pitch, report: report, cursor: _position),
          if (report != null)
            Wrap(spacing: 16, children: [
              Text('단조로운 구간 ${report.flatRanges.length}곳',
                  style: theme.textTheme.bodySmall),
              Text('문장 끝이 올라간 곳 ${report.risingEnds.length}곳',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.orange.shade800)),
            ]),
          const SizedBox(height: 24),
        ],
        Text('다르게 들린 단어', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (widget.marks != null)
          MarkedScript(marks: widget.marks!)
        else if (widget.error != null)
          Text(widget.error!)
        else if (widget.status == ResultStatus.metricsReady) ...[
          Text('원고와 맞춰 보는 중이에요 (${(widget.progress * 100).round()}%)'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: widget.progress),
        ],
        const SizedBox(height: 24),
        if (widget.onRetry != null)
          OutlinedButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 연습'),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.headlineMedium),
        ]),
      ),
    );
  }
}
