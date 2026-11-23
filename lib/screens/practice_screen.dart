import 'package:app_settings/app_settings.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/recorder.dart';
import '../data/models.dart';
import '../practice/practice_controller.dart';
import '../providers.dart';
import '../widgets/pitch_line.dart';
import 'result_screen.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key, required this.script, this.onOpenHistory});
  final Script script;
  final void Function(BuildContext context, Script script)? onOpenHistory;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  late final PracticeController _c;

  @override
  void initState() {
    super.initState();
    _c = PracticeController(
      script: widget.script,
      recorder: ref.read(recorderProvider),
      transcriber: ref.read(transcriberProvider),
      sessions: ref.read(sessionRepositoryProvider),
    );
    _c.addListener(_onChange);
  }

  PracticePhase? _lastPhase;
  void _onChange() {
    final phase = _c.state.phase;
    if (phase == PracticePhase.permissionDenied && _lastPhase != phase) {
      _showPermissionGuide();
    }
    _lastPhase = phase;
    setState(() {});
  }

  Future<void> _showPermissionGuide() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('마이크를 쓸 수 없어요'),
          content: const Text('연습을 녹음하려면 설정에서 이 앱의 마이크 권한을 켜 주세요.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
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
    return PopScope(
      canPop: !recording,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && recording) {
          await _c.stop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.script.title),
          actions: [
            if (widget.onOpenHistory != null && !recording)
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: '연습 기록',
                onPressed: () => widget.onOpenHistory!(context, widget.script),
              ),
          ],
        ),
        body: s.phase == PracticePhase.result
            ? ResultView(
                script: widget.script,
                session: s.session,
                intonation: s.intonation,
                status: s.resultStatus ?? ResultStatus.complete,
                marks: s.marks,
                progress: s.transcribeProgress,
                message: s.message,
                error: s.error,
                interrupted: s.interrupted,
                onRetry: _c.reset,
                playerFactory: ref.read(playerFactoryProvider),
              )
            : _Reading(script: widget.script, state: s, onToggle: _toggle),
      ),
    );
  }

  Future<void> _toggle() async {
    if (_c.state.phase == PracticePhase.recording) {
      await _c.stop();
    } else {
      await _c.start();
    }
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.script, required this.state, required this.onToggle});
  final Script script;
  final PracticeState state;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recording = state.phase == PracticePhase.recording;
    return SafeArea(
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Text(script.body,
                style: theme.textTheme.headlineSmall?.copyWith(height: 1.7)),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: PitchLine(
            pitch: state.livePitch,
            window: const Duration(seconds: 8),
            height: 90,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(children: [
            Text(
              '${formatDuration(state.elapsed)} / ${formatDuration(maxRecordDuration)}',
              style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onToggle,
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 56),
                backgroundColor: recording ? theme.colorScheme.error : null,
              ),
              icon: Icon(recording ? Icons.stop : Icons.mic),
              label: Text(recording ? '정지' : '녹음 시작'),
            ),
          ]),
        ),
      ]),
    );
  }
}
