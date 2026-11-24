import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../analysis/compare.dart';
import '../analysis/intonation.dart';
import '../analysis/live_metrics.dart';
import '../analysis/pitch.dart';
import '../analysis/script_tracker.dart';
import '../analysis/syllables.dart';
import '../audio/recorder.dart';
import '../audio/wav.dart';
import '../data/models.dart';
import '../data/session_repository.dart';
import '../speech/live_transcriber.dart';
import '../speech/transcriber.dart';

enum PracticePhase { idle, recording, permissionDenied, result }

/// 결과 화면 상태. 시간·빠르기·억양은 녹음이 끝나자마자 [metricsReady]로 보여주고,
/// 원고 비교는 인식이 끝나면 [complete]가 된다.
enum ResultStatus { metricsReady, complete }

const noVoiceMessage = '목소리가 들리지 않았어요';
const transcribeFailedMessage = '다르게 들린 단어를 찾지 못했어요. 다시 녹음해 보세요.';

/// 목소리가 계속 들어오는데 들린 글이 이 시간 넘게 늘지 않으면 실시간 인식이 늦다고 본다.
const liveLagLimit = Duration(seconds: 6);

/// 이보다 큰 소리를 "목소리가 들어오는 중"으로 본다 (dBFS).
const voiceDb = -40.0;

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
    this.position = 0,
    this.progress = 0,
    this.speed,
    this.loudness = LoudLevel.quiet,
    this.waveform = const [],
    this.estimating = false,
    this.remaining = Duration.zero,
    this.resultStatus,
    this.session,
    this.intonation,
    this.marks,
    this.transcript,
    this.transcribeProgress = 0,
    this.message,
    this.error,
    this.interrupted = false,
  });

  final PracticePhase phase;

  /// 녹음 중 경과 시간.
  final Duration elapsed;

  /// 녹음 중 실시간 억양 선.
  final List<PitchPoint> livePitch;

  /// 원고에서 지금 읽는 위치 (읽는 소리 단위)와 비율.
  final int position;
  final double progress;

  /// 최근 속도. 아직 모르면 null.
  final SpeedLevel? speed;
  final LoudLevel loudness;

  /// 0.1초마다의 소리 크기(dBFS), 최근 [waveformBars]개.
  final List<double> waveform;

  /// 실시간 인식 대신 목소리 시간으로 위치를 추정하는 중이면 true.
  final bool estimating;

  /// 남은 원고를 읽는 데 걸릴 시간.
  final Duration remaining;

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
        position: position,
        progress: progress,
        speed: speed,
        loudness: loudness,
        waveform: waveform,
        estimating: estimating,
        remaining: remaining,
        resultStatus: resultStatus ?? this.resultStatus,
        session: session,
        intonation: intonation,
        marks: marks ?? this.marks,
        transcript: transcript ?? this.transcript,
        transcribeProgress: transcribeProgress ?? this.transcribeProgress,
        message: message,
        error: error ?? this.error,
        interrupted: interrupted,
      );
}

class PracticeController extends ChangeNotifier {
  PracticeController({
    required this.script,
    required this._recorder,
    required this._transcriber,
    required this._sessions,
    this.live,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Script script;
  final Recorder _recorder;
  final Transcriber _transcriber;
  final SessionRepository _sessions;

  /// 실시간 인식. 없으면 위치를 목소리 시간으로만 추정한다.
  final LiveTranscriber? live;
  final DateTime Function() _now;

  PracticeState _state = const PracticeState();
  PracticeState get state => _state;

  StreamSubscription<Float32List>? _frameSub;
  _LivePitch _live = _LivePitch();
  Future<void>? _finishing;
  bool _disposed = false;

  // 녹음 한 번 동안의 실시간 상태
  late ScriptTracker _tracker = ScriptTracker(script.body);
  SpeedMeter _meter = SpeedMeter();
  LiveSession? _session;
  StreamSubscription<String>? _heardSub;
  final List<Uint8List> _pendingPcm = [];
  bool _liveReady = false;
  bool _liveFailed = false;
  bool _lagged = false;
  int _lastHeardLength = 0;
  Duration _voicedSinceGrowth = Duration.zero;
  int _estimateBase = 0;
  Duration _voicedEstimate = Duration.zero;
  final List<double> _bars = [];
  int _barsDone = 0;

  /// 인식과 원고 비교가 끝나면 완료된다 (인식을 시작하지 않았으면 null).
  Future<void>? transcription;

  /// 녹음이 끝나고 결과(시간·빠르기·억양)가 채워지면 완료된다.
  Future<void> get settled => _finishing ?? Future.value();

  bool get _estimating => live == null || _liveFailed || _lagged || !_liveReady;

  void _set(PracticeState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_state.phase == PracticePhase.recording) return;
    _live = _LivePitch();
    _tracker = ScriptTracker(script.body);
    _meter = SpeedMeter();
    _session = null;
    _pendingPcm.clear();
    _liveReady = false;
    _liveFailed = false;
    _lagged = false;
    _lastHeardLength = 0;
    _voicedSinceGrowth = Duration.zero;
    _estimateBase = 0;
    _voicedEstimate = Duration.zero;
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
    // 모델을 올리는 몇 초 동안에도 녹음은 바로 시작하고, 위치는 추정으로 시작한다.
    if (live != null) unawaited(_startLive());
  }

  Future<void> _startLive() async {
    try {
      final s = await live!.start();
      if (_state.phase != PracticePhase.recording || _finishing != null) {
        unawaited(s.stop().then<void>((_) {}, onError: (_) {}));
        return;
      }
      _session = s;
      for (final pcm in _pendingPcm) {
        s.feed(pcm);
      }
      _pendingPcm.clear();
      _heardSub = s.partials.listen(_onHeard, onError: (Object e) {
        debugPrint('live recognition error: $e');
        _lagged = true;
        _estimateBase = _tracker.position;
        _voicedEstimate = Duration.zero;
      });
      _liveReady = true;
      _publish();
    } catch (e) {
      debugPrint('live recognition unavailable: $e');
      _liveFailed = true;
      _pendingPcm.clear();
      _publish();
    }
  }

  void _onHeard(String text) {
    if (text.length > _lastHeardLength) {
      _lastHeardLength = text.length;
      _voicedSinceGrowth = Duration.zero;
    }
    if (!_lagged) _tracker.onHeard(text);
    _publish();
  }

  void _onFrames(Float32List frame) {
    _live.add(frame);
    final pcm = toPcm16(frame);
    if (_session != null) {
      _session!.feed(pcm);
    } else if (live != null && !_liveFailed) {
      _pendingPcm.add(pcm);
    }

    final frameDuration = Duration(
        microseconds: frame.length * Duration.microsecondsPerSecond ~/ recordSampleRate);
    if (dbfs(frame) > voiceDb) {
      if (_estimating) {
        _voicedEstimate += frameDuration;
      } else {
        _voicedSinceGrowth += frameDuration;
        if (_voicedSinceGrowth > liveLagLimit) {
          _lagged = true;
          _estimateBase = _tracker.position;
          _voicedEstimate = Duration.zero;
        }
      }
    }
    if (_estimating) {
      // 실시간 인식이 멈춘 동안 잰 속도는 믿을 수 없으므로 보통 속도로 추정한다.
      _tracker.onEstimate(
          _estimateBase + (_voicedEstimate.inMicroseconds / 60e6 * defaultSpm).round());
    }
    _publish();
  }

  /// 녹음 중 화면 상태를 다시 만든다.
  void _publish({PracticePhase? phase}) {
    final elapsed = Duration(
        microseconds: _live.length * Duration.microsecondsPerSecond ~/ recordSampleRate);
    _meter.add(elapsed, _tracker.position);

    final barSamples = recordSampleRate * waveformBar.inMilliseconds ~/ 1000;
    while ((_barsDone + 1) * barSamples <= _live.length) {
      _bars.add(dbfs(_live.slice(_barsDone * barSamples, (_barsDone + 1) * barSamples)));
      _barsDone++;
    }
    if (_bars.length > waveformBars) _bars.removeRange(0, _bars.length - waveformBars);

    final loudSamples = recordSampleRate * loudnessWindow.inMilliseconds ~/ 1000;
    final recent = _live.slice((_live.length - loudSamples).clamp(0, _live.length), _live.length);
    final spm = _meter.spm;

    _set(PracticeState(
      phase: phase ?? _state.phase,
      elapsed: elapsed,
      livePitch: _live.points,
      position: _tracker.position,
      progress: _tracker.progress,
      speed: spm == null ? null : speedLevel(spm),
      loudness: loudLevel(dbfs(recent)),
      waveform: List.unmodifiable(_bars),
      estimating: _estimating,
      remaining: remainingTime(_tracker.total - _tracker.position, spm),
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
    _set(const PracticeState());
  }

  Future<void> _finish(RecordResult r) => _finishing ??= _finishRecording(r);

  /// 실시간 세션을 닫고 최종 글을 받는다. 세션이 없거나 오류면 null.
  Future<String?> _closeLive(LiveSession? s) async {
    await _heardSub?.cancel();
    _heardSub = null;
    if (s == null) return null;
    try {
      return await s.stop();
    } catch (e) {
      debugPrint('live recognition stop failed: $e');
      return null;
    }
  }

  Future<void> _finishRecording(RecordResult r) async {
    await _frameSub?.cancel();
    _frameSub = null;
    final s = _session;
    _session = null;
    // 실시간 인식이 끝까지 정상이었는지는 지금 정해진다.
    final useLive = s != null && !_lagged && !_liveFailed;
    final liveText = _closeLive(s);

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
      unawaited(liveText);
      final f = File(r.wavPath);
      if (f.existsSync()) f.deleteSync();
      _set(PracticeState(
        phase: PracticePhase.result,
        resultStatus: ResultStatus.complete,
        intonation: intonation,
        message: noVoiceMessage,
        interrupted: r.interrupted,
      ));
      return;
    }

    final elapsed = voicedSpan(pitch) ?? r.elapsed;
    final draft = PracticeSession(
      scriptId: script.id!,
      audioPath: r.wavPath,
      elapsed: elapsed,
      syllablesPerMinute: syllablesPerMinute(countSyllables(script.body), elapsed),
      pitch: pitch,
      createdAt: _now(),
    );
    final id = await _sessions.add(draft);
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
    ));
    transcription = _transcribe(session, useLive ? liveText : null);
  }

  /// [liveText]가 있으면(실시간 인식이 끝까지 정상) 그 글로 비교하고 파일을 다시 인식하지 않는다.
  /// 없으면 녹음 파일 전체를 인식한다.
  Future<void> _transcribe(PracticeSession session, Future<String?>? liveText) async {
    Future<String> fromFile() async => (await _transcriber.transcribe(
          session.audioPath,
          onProgress: (v) => _set(_state.copyWith(transcribeProgress: v)),
        ))
            .text;
    try {
      final text = liveText == null
          ? await fromFile()
          : (await liveText) ?? await fromFile();
      final marks = compareToScript(script.body, text);
      await _sessions.updateMarks(session.id!, marks, transcript: text);
      _set(_state.copyWith(
        resultStatus: ResultStatus.complete,
        marks: marks,
        transcript: text,
        transcribeProgress: 1,
      ));
    } catch (e) {
      debugPrint('transcription failed: $e');
      _set(_state.copyWith(
        resultStatus: ResultStatus.complete,
        error: transcribeFailedMessage,
      ));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _frameSub?.cancel();
    // 녹음 중에 화면을 나가면 녹음을 멈춘다. finished 처리에서 기록이 저장되고 세션도 닫힌다.
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
