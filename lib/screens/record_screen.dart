import 'package:app_settings/app_settings.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analysis/script_layout.dart';
import '../data/models.dart';
import '../practice/practice_controller.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/memo_sheet.dart';
import '../widgets/prompter.dart';
import '../widgets/studio.dart';
import 'history_screen.dart';
import 'result_screen.dart';

/// 녹음 탭 (시안 1·2): 프롬프터, 속도·크기, 파형, 진행 막대, 녹음 버튼.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key, required this.script});
  final Script script;

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  late final PracticeController _c;
  PracticePhase? _lastPhase;
  ResultStatus? _lastStatus;

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
    // 저장해 둔 진행 속도를 불러온다.
    ref.read(settingsRepositoryProvider).pace().then((p) {
      if (mounted) _c.setPace(p);
    });
  }

  Future<void> _changePace(double v) async {
    _c.setPace(v);
    await ref.read(settingsRepositoryProvider).setPace(_c.pace);
  }

  void _onChange() {
    final s = _c.state;
    if (s.phase == PracticePhase.permissionDenied && _lastPhase != s.phase) {
      _showPermissionGuide();
    }
    // 녹음이 저장되거나 비교가 끝나면 자주 틀림·기록을 다시 계산한다.
    if (s.resultStatus != _lastStatus && s.resultStatus != null) {
      ref.invalidate(scriptDetailsProvider(widget.script));
      ref.invalidate(sessionsForScriptProvider(widget.script.id!));
    }
    _lastPhase = s.phase;
    _lastStatus = s.resultStatus;
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

  Future<void> _toggle() async {
    if (_c.state.phase == PracticePhase.recording) {
      await _c.stop();
    } else {
      await _c.start();
    }
  }

  Future<void> _cyclePause(ScriptDetails d, int i) async {
    final next = Map.of(d.pauses);
    final p = cyclePause(next[i] ?? Pause.none);
    if (p == Pause.none) {
      next.remove(i);
    } else {
      next[i] = p;
    }
    await ref.read(scriptRepositoryProvider).setPauses(widget.script.id!, next);
    ref.invalidate(scriptDetailsProvider(widget.script));
  }

  Future<void> _editMemo(ScriptDetails d, int i) async {
    final edit = await showMemoSheet(context,
        word: d.words[i], wordIndex: i, stats: d.stats, memo: d.memos[i]);
    if (edit == null) return;
    await ref.read(memoRepositoryProvider).save(Memo(
          scriptId: widget.script.id!,
          wordIndex: i,
          kind: edit.kind,
          text: edit.text,
          createdAt: DateTime.now(),
        ));
    ref.invalidate(scriptDetailsProvider(widget.script));
  }

  @override
  Widget build(BuildContext context) {
    final s = _c.state;
    final recording = s.phase == PracticePhase.recording;
    final details = ref.watch(scriptDetailsProvider(widget.script));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(title: widget.script.title, onAir: recording),
            if (s.phase == PracticePhase.result)
              Expanded(
                child: ResultView(
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
                ),
              )
            else ...[
              const SizedBox(height: 12),
              const _Legend(),
              Expanded(
                child: switch (details) {
                  AsyncData(:final value) => _body(value, s, recording),
                  AsyncError() => const Center(child: Text('원고를 불러오지 못했어요')),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(ScriptDetails d, PracticeState s, bool recording) {
    // 녹음을 시작할 때 쓸 끊어 읽기 표시를 컨트롤러에 알려 둔다 (남은 시간도 다시 계산됨).
    if (!recording && !identical(_c.pauses, d.pauses)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _c.state.phase != PracticePhase.recording) _c.pauses = d.pauses;
      });
    }
    final offsets = syllableOffsets(d.words);
    final total = offsets.last;
    final dots = [
      for (final i in d.stats.wrong.keys)
        if (d.stats.isFrequent(i) && total > 0) offsets[i] / total,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Prompter(
                  words: d.words,
                  pauses: d.pauses,
                  memos: d.memos,
                  stats: d.stats,
                  currentSentence: s.sentence,
                  karaoke: recording && s.karaoke,
                  activeWord: s.word,
                  wordFill: s.wordFill,
                  editable: !recording,
                  onTapGap: (i) => _cyclePause(d, i),
                  onLongPressWord: (i) => _editMemo(d, i),
                ),
              ),
              if (recording && s.countdown != null) CountdownBadge(value: s.countdown!),
            ],
          ),
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 6,
          children: [
            PaceControl(pace: _c.pace, enabled: !recording, onChanged: _changePace),
            LevelChips(
                label: '크기',
                options: const ['작게', '적당', '크게'],
                selected: recording ? loudIndex(s.loudness) : null),
          ],
        ),
        const SizedBox(height: 8),
        Waveform(bars: s.waveform),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('대본 ${(s.progress * 100).round()}%',
                style: const TextStyle(color: Palette.muted)),
            const Spacer(),
            Text('남은 ${formatDuration(s.remaining)}',
                style: const TextStyle(color: Palette.faint)),
          ],
        ),
        const SizedBox(height: 6),
        ScriptProgressBar(progress: s.progress, dots: dots),
        const SizedBox(height: 14),
        TapeControls(recording: recording, onPressed: _toggle),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onAir});
  final String title;
  final bool onAir;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('온에어.', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, color: Palette.faint)),
              ],
            ),
          ),
          OnAirBadge(active: onAir),
        ],
      );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(color: Palette.muted, fontSize: 14);
    const mark = TextStyle(color: Palette.red, fontSize: 14);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text.rich(TextSpan(children: [TextSpan(text: '/ ', style: mark), TextSpan(text: '쉼', style: label)])),
        const Text.rich(TextSpan(children: [TextSpan(text: '// ', style: mark), TextSpan(text: '숨', style: label)])),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 20, height: 6, color: Palette.emphasis),
          const SizedBox(width: 4),
          const Text('강조', style: label),
        ]),
        const Text.rich(TextSpan(children: [TextSpan(text: '〰 ', style: mark), TextSpan(text: '자주 틀림', style: label)])),
      ],
    );
  }
}
