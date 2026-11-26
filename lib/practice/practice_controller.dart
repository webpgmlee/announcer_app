import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../analysis/compare.dart';
import '../analysis/intonation.dart';
import '../analysis/karaoke.dart';
import '../analysis/live_metrics.dart';
import '../analysis/pitch.dart';
import '../analysis/script_layout.dart';
import '../analysis/syllable_rate.dart';
import '../analysis/syllables.dart';
import '../audio/recorder.dart';
import '../audio/wav.dart';
import '../data/models.dart';
import '../data/session_repository.dart';
import '../speech/transcriber.dart';

enum PracticePhase { idle, recording, permissionDenied, result }

/// 결과 화면 상태. 시간·빠르기·억양은 녹음이 끝나자마자 [metricsReady]로 보여주고,
/// 원고 비교는 인식이 끝나면 [complete]가 된다.
enum ResultStatus { metricsReady, complete }

const noVoiceMessage = '목소리가 들리지 않았어요';
const transcribeFailedMessage = '다르게 들린 단어를 찾지 못했어요. 다시 녹음해 보세요.';

/// 파형 막대 하나의 길이와 보여줄 개수.
const waveformBar = Duration(milliseconds: 100);
const waveformBars = 40;

/// 소리 크기를 판단하는 최근 구간.
const loudnessWindow = Duration(milliseconds: 500);

class PracticeState {
  const PracticeState({
    this.phase = PracticePhase.idle,
    this.elapsed = Duration.zero,
    this.livePitch = const [],
    this.countdown,
    this.karaoke = false,
    this.word = 0,
    this.wordFill = 0,
    this.sentence = 0,
    this.position = 0,
    this.progress = 0,
    this.loudness = LoudLevel.quiet,
    this.waveform = const [],
    this.remaining = Duration.zero,
    this.paceFeedback = PaceFeedback.none,
    this.resultStatus,
    this.session,
    this.intonation,
    this.marks,
    this.transcript,
    this.transcribeProgress = 0,
    this.message,
    this.error,
    this.interrupted = false,
    this.voiced,
  });

  final PracticePhase phase;

  /// 녹음 중 경과 시간.
  final Duration elapsed;

  /// 녹음 중 실시간 억양 선.
  final List<PitchPoint> livePitch;

  /// 진행 시작 전 카운트다운 숫자(3, 2, 1). 진행 중이면 null.
  final int? countdown;

  /// 노래방식 진행 중이면 true.
  final bool karaoke;

  /// 지금 채우는 어절, 그 어절을 채운 비율, 지금 문장.
  final int word;
  final double wordFill;
  final int sentence;

  /// 원고에서 채운 위치(읽는 소리 단위)와 비율.
  final int position;
  final double progress;
  final LoudLevel loudness;

  /// 0.1초마다의 소리 크기(dBFS), 최근 [waveformBars]개.
  final List<double> waveform;

  /// 남은 원고를 지금 속도로 읽는 데 걸릴 시간.
  final Duration remaining;

  /// 진행 속도보다 빠르거나 느리게 읽고 있으면 알린다 (진행 중에만).
  final PaceFeedback paceFeedback;

  final ResultStatus? resultStatus;
  final PracticeSession? session;
  final IntonationReport? intonation;
  final List<WordMark>? marks;
  final String? transcript;
  final double transcribeProgress;

  /// 결과 대신 보여줄 안내 (예: 목소리가 들리지 않았어요).
  final String? message;

  /// 원고 비교를 하지 못했을 때의 안내.
  final String? error;

  /// 전화 수신·백그라운드 전환으로 녹음이 끊겼으면 true.
  final bool interrupted;

  /// 목소리가 난 구간의 길이 (처음 목소리부터 마지막 목소리까지). 결과가 나오면 채워진다.
  final Duration? voiced;

  PracticeState copyWith({
    ResultStatus? resultStatus,
    List<WordMark>? marks,
    String? transcript,
    double? transcribeProgress,
    String? error,
  }) =>
      PracticeState(
        phase: phase,
        elapsed: elapsed,
        livePitch: livePitch,
        countdown: countdown,
        karaoke: karaoke,
        word: word,
        wordFill: wordFill,
        sentence: sentence,
        position: position,
        progress: progress,
        loudness: loudness,
        waveform: waveform,
        remaining: remaining,
        paceFeedback: paceFeedback,
        resultStatus: resultStatus ?? this.resultStatus,
        session: session,
        intonation: intonation,
        marks: marks ?? this.marks,
        transcript: transcript ?? this.transcript,
        transcribeProgress: transcribeProgress ?? this.transcribeProgress,
        message: message,
        error: error ?? this.error,
        interrupted: interrupted,
        voiced: voiced,
      );
}

class PracticeController extends ChangeNotifier {
  PracticeController({
    required this.script,
    required this._recorder,
    required this._transcriber,
    required this._sessions,
    double pace = defaultPace,
    this.keepRecording = true,
    DateTime Function()? now,
  })  : _pace = clampPace(pace),
        _now = now ?? DateTime.now,
        _words = scriptWords(script.body) {
    _pauses = autoPauses(_words);
    _state = PracticeState(remaining: KaraokeTimeline(_words, _pauses, _pace).total);
  }

  final Script script;

  /// false면 퍼펙트딕션 도전처럼 녹음관리 기록을 만들지 않고, 인식이 끝나면 녹음 파일을 지운다.
  final bool keepRecording;
  final Recorder _recorder;
  final Transcriber _transcriber;
  final SessionRepository _sessions;
  final DateTime Function() _now;
  final List<String> _words;

  /// 진행 시간표에 쓸 끊어 읽기 표시. 녹음을 시작할 때의 값을 쓴다.
  late Map<int, Pause> _pauses;
  Map<int, Pause> get pauses => _pauses;
  set pauses(Map<int, Pause> p) {
    _pauses = p;
    if (_state.phase == PracticePhase.idle) _idleState();
  }

  double _pace;

  /// 노래방식 진행 속도 (1분당 음절).
  double get pace => _pace;

  /// 녹음 전에만 바꿀 수 있다. 범위(200~500, 10 단위)로 맞춘다.
  void setPace(double v) {
    if (_state.phase == PracticePhase.recording) return;
    _pace = clampPace(v);
    if (_state.phase != PracticePhase.result) _idleState();
  }

  PracticeState _state = const PracticeState();
  PracticeState get state => _state;

  StreamSubscription<Float32List>? _frameSub;
  _LivePitch _live = _LivePitch();
  Future<void>? _finishing;
  bool _disposed = false;
  late KaraokeTimeline _timeline = KaraokeTimeline(_words, _pauses, _pace);
  bool _autoStopped = false;
  Duration _lastVoice = Duration.zero;
  SyllableRateMeter _rate = SyllableRateMeter();
  PaceAdvisor _advisor = PaceAdvisor(pace: defaultPace);
  PaceFeedback _feedback = PaceFeedback.none;
  final List<double> _bars = [];
  int _barsDone = 0;

  /// 인식과 원고 비교가 끝나면 완료된다 (인식을 시작하지 않았으면 null).
  Future<void>? transcription;

  /// 녹음이 끝나고 결과(시간·빠르기·억양)가 채워지면 완료된다.
  Future<void> get settled => _finishing ?? Future.value();

  void _set(PracticeState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  /// 녹음 전 화면: 원고 처음, 남은 시간은 전체 진행 시간.
  void _idleState() {
    final t = KaraokeTimeline(_words, _pauses, _pace);
    _set(PracticeState(remaining: t.total));
  }

  Future<void> start() async {
    if (_state.phase == PracticePhase.recording) return;
    _live = _LivePitch();
    _timeline = KaraokeTimeline(_words, _pauses, _pace);
    _autoStopped = false;
    _lastVoice = Duration.zero;
    _rate = SyllableRateMeter();
    _advisor = PaceAdvisor(pace: _pace);
    _feedback = PaceFeedback.none;
    _bars.clear();
    _barsDone = 0;
    _finishing = null;
    transcription = null;

    final r = await _recorder.start();
    if (r == RecordStart.permissionDenied) {
      _set(const PracticeState(phase: PracticePhase.permissionDenied));
      return;
    }
    _frameSub = _recorder.pcmFrames.listen(_onFrames);
    _publish(phase: PracticePhase.recording);
    // 5분 도달, 전화 수신 등으로 녹음이 저절로 끝나도 결과를 낸다.
    unawaited(_recorder.finished.then(_finish, onError: (_) {}));
  }

  void _onFrames(Float32List frame) {
    _live.add(frame);
    // 진행이 시작된 뒤의 소리로만 말 빠르기를 잰다 (카운트다운 동안은 재지 않음).
    final now = _clock - countdownLength;
    if (now >= Duration.zero) {
      _rate.add(frame);
      _feedback = _advisor.update(now, _rate.spm);
    }
    _publish();
    if (dbfs(frame) > _voiceDb) _lastVoice = _clock;
    // 원고 진행이 끝나고 목소리가 1.5초 멈추면 녹음을 멈추고 저장한다.
    // 진행보다 늦게 읽고 있으면 끊지 않고 기다리되, 소리가 계속 나도 10초 뒤에는 멈춘다.
    final over = _clock - countdownLength - _timeline.total;
    final quietFor = _clock - _lastVoice;
    if (!_autoStopped &&
        over >= Duration.zero &&
        ((over >= endHold && quietFor >= endHold) || over >= maxOvertime)) {
      _autoStopped = true;
      unawaited(stop());
    }
  }

  /// 이보다 큰 소리를 "말하는 중"으로 본다 (dBFS).
  static const _voiceDb = -40.0;

  /// 녹음된 소리 길이. 진행 시계로 쓴다 (녹음과 진행이 어긋나지 않게).
  Duration get _clock =>
      Duration(microseconds: _live.length * Duration.microsecondsPerSecond ~/ recordSampleRate);

  /// 녹음 중 화면 상태를 다시 만든다.
  void _publish({PracticePhase? phase}) {
    final elapsed = _clock;
    final t = elapsed - countdownLength;
    final f = _timeline.at(t);
    final countdown = t < Duration.zero ? (-t.inMicroseconds / 1e6).ceil() : null;

    final barSamples = recordSampleRate * waveformBar.inMilliseconds ~/ 1000;
    while ((_barsDone + 1) * barSamples <= _live.length) {
      _bars.add(dbfs(_live.slice(_barsDone * barSamples, (_barsDone + 1) * barSamples)));
      _barsDone++;
    }
    if (_bars.length > waveformBars) _bars.removeRange(0, _bars.length - waveformBars);
    final loudSamples = recordSampleRate * loudnessWindow.inMilliseconds ~/ 1000;
    final recent =
        _live.slice((_live.length - loudSamples).clamp(0, _live.length), _live.length);

    _set(PracticeState(
      phase: phase ?? _state.phase,
      elapsed: elapsed,
      livePitch: _live.points,
      countdown: countdown,
      karaoke: countdown == null,
      word: f.word,
      wordFill: f.wordFill,
      sentence: f.sentence,
      position: f.position,
      progress: f.progress,
      loudness: loudLevel(dbfs(recent)),
      waveform: List.unmodifiable(_bars),
      remaining: f.remaining,
      paceFeedback: countdown == null ? _feedback : PaceFeedback.none,
    ));
  }

  Future<void> stop() async {
    if (_state.phase != PracticePhase.recording) return settled;
    final r = await _recorder.stop();
    await _finish(r);
  }

  /// 결과를 본 뒤 다시 연습할 준비를 한다.
  void reset() {
    if (_state.phase == PracticePhase.recording) return;
    _idleState();
  }

  Future<void> _finish(RecordResult r) => _finishing ??= _finishRecording(r);

  Future<void> _finishRecording(RecordResult r) async {
    await _frameSub?.cancel();
    _frameSub = null;

    final expected =
        r.elapsed.inMicroseconds * recordSampleRate ~/ Duration.microsecondsPerSecond;
    final List<PitchPoint> pitch;
    if (_live.length >= expected * 0.95 && _live.length > 0) {
      pitch = _live.points;
    } else {
      final path = r.wavPath;
      List<PitchPoint> fromFile;
      try {
        fromFile = await Isolate.run(() => analyzePitch(readWav(path)));
      } catch (e) {
        // 녹음 파일을 읽지 못하면 목소리가 없던 것으로 처리한다 (앱이 멈추지 않게).
        debugPrint('could not read recording: $e');
        fromFile = const [];
      }
      pitch = fromFile;
    }
    final intonation = analyzeIntonation(pitch);

    if (intonation.noVoice) {
      final f = File(r.wavPath);
      if (f.existsSync()) f.deleteSync();
      _set(PracticeState(
        phase: PracticePhase.result,
        resultStatus: ResultStatus.complete,
        intonation: intonation,
        message: noVoiceMessage,
        interrupted: r.interrupted,
        voiced: Duration.zero,
      ));
      return;
    }

    final elapsed = voicedSpan(pitch) ?? r.elapsed;
    final draft = PracticeSession(
      scriptId: script.id ?? -1,
      audioPath: r.wavPath,
      elapsed: elapsed,
      syllablesPerMinute: syllablesPerMinute(countSyllables(script.body), elapsed),
      pitch: pitch,
      createdAt: _now(),
    );
    // 도전 모드(퍼펙트딕션)는 녹음관리 기록을 만들지 않는다.
    final id = keepRecording ? await _sessions.add(draft) : null;
    final session = PracticeSession(
      id: id,
      scriptId: draft.scriptId,
      audioPath: draft.audioPath,
      elapsed: draft.elapsed,
      syllablesPerMinute: draft.syllablesPerMinute,
      pitch: draft.pitch,
      createdAt: draft.createdAt,
    );
    _set(PracticeState(
      phase: PracticePhase.result,
      resultStatus: ResultStatus.metricsReady,
      session: session,
      intonation: intonation,
      interrupted: r.interrupted,
      voiced: elapsed,
    ));
    transcription = _transcribe(session);
  }

  Future<void> _transcribe(PracticeSession session) async {
    try {
      final t = await _transcriber.transcribe(
        session.audioPath,
        onProgress: (v) => _set(_state.copyWith(transcribeProgress: v)),
      );
      final marks = compareToScript(script.body, t.text);
      if (keepRecording) {
        await _sessions.updateMarks(session.id!, marks, transcript: t.text);
      }
      _set(_state.copyWith(
        resultStatus: ResultStatus.complete,
        marks: marks,
        transcript: t.text,
        transcribeProgress: 1,
      ));
    } catch (e) {
      debugPrint('transcription failed: $e');
      _set(_state.copyWith(
        resultStatus: ResultStatus.complete,
        error: transcribeFailedMessage,
      ));
    } finally {
      // 도전 모드는 점수만 남기고 녹음 파일은 지운다.
      if (!keepRecording) {
        final f = File(session.audioPath);
        if (f.existsSync()) f.deleteSync();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _frameSub?.cancel();
    // 녹음 중에 화면을 나가면 녹음을 멈춘다. finished 처리에서 기록이 저장된다.
    if (_state.phase == PracticePhase.recording) unawaited(_recorder.stop());
    super.dispose();
  }
}

/// 처음 목소리가 난 때부터 마지막 목소리까지. 목소리가 없으면 null.
Duration? voicedSpan(List<PitchPoint> pitch) {
  final voiced = pitch.where((p) => p.hz != null);
  if (voiced.isEmpty) return null;
  final hop = pitch.length > 1 ? pitch[1].t - pitch[0].t : Duration.zero;
  return voiced.last.t - voiced.first.t + hop;
}

/// 녹음 중 들어오는 샘플을 이어 붙이며 새 프레임만 분석한다.
class _LivePitch {
  static const _hop = Duration(milliseconds: 10);
  static const _hopSamples = recordSampleRate ~/ 100;

  Float32List _buf = Float32List(recordSampleRate * 10);
  int length = 0;
  int _frames = 0;
  final List<PitchPoint> _points = [];
  List<PitchPoint> get points => List.unmodifiable(_points);

  Float32List slice(int from, int to) => Float32List.sublistView(_buf, from, to);

  void add(Float32List f) {
    if (length + f.length > _buf.length) {
      var cap = _buf.length * 2;
      while (cap < length + f.length) {
        cap *= 2;
      }
      _buf = Float32List(cap)..setRange(0, length, _buf);
    }
    _buf.setRange(length, length + f.length, f);
    length += f.length;

    final start = _frames * _hopSamples;
    final fresh = analyzePitch(Float32List.sublistView(_buf, start, length));
    for (final p in fresh) {
      _points.add(PitchPoint(t: p.t + _hop * _frames, hz: p.hz));
    }
    _frames += fresh.length;
  }
}
