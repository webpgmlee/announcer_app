import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../analysis/compare.dart';
import '../analysis/intonation.dart';
import '../analysis/pitch.dart';
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

class PracticeState {
  const PracticeState({
    this.phase = PracticePhase.idle,
    this.elapsed = Duration.zero,
    this.livePitch = const [],
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
    PracticePhase? phase,
    Duration? elapsed,
    List<PitchPoint>? livePitch,
    ResultStatus? resultStatus,
    PracticeSession? session,
    IntonationReport? intonation,
    List<WordMark>? marks,
    String? transcript,
    double? transcribeProgress,
    String? message,
    String? error,
    bool? interrupted,
  }) =>
      PracticeState(
        phase: phase ?? this.phase,
        elapsed: elapsed ?? this.elapsed,
        livePitch: livePitch ?? this.livePitch,
        resultStatus: resultStatus ?? this.resultStatus,
        session: session ?? this.session,
        intonation: intonation ?? this.intonation,
        marks: marks ?? this.marks,
        transcript: transcript ?? this.transcript,
        transcribeProgress: transcribeProgress ?? this.transcribeProgress,
        message: message ?? this.message,
        error: error ?? this.error,
        interrupted: interrupted ?? this.interrupted,
      );
}

class PracticeController extends ChangeNotifier {
  PracticeController({
    required this.script,
    required this._recorder,
    required this._transcriber,
    required this._sessions,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Script script;
  final Recorder _recorder;
  final Transcriber _transcriber;
  final SessionRepository _sessions;
  final DateTime Function() _now;

  PracticeState _state = const PracticeState();
  PracticeState get state => _state;

  StreamSubscription<Float32List>? _frameSub;
  _LivePitch _live = _LivePitch();
  Future<void>? _finishing;
  bool _disposed = false;

  /// 인식과 원고 비교가 끝나면 완료된다 (인식을 시작하지 않았으면 null).
  Future<void>? transcription;

  /// 녹음이 끝나고 결과(시간·빠르기·억양)가 채워지면 완료된다.
  Future<void> get settled => _finishing ?? Future.value();

  void _set(PracticeState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_state.phase == PracticePhase.recording) return;
    _live = _LivePitch();
    _finishing = null;
    transcription = null;
    final r = await _recorder.start();
    if (r == RecordStart.permissionDenied) {
      _set(const PracticeState(phase: PracticePhase.permissionDenied));
      return;
    }
    _frameSub = _recorder.pcmFrames.listen(_onFrames);
    _set(const PracticeState(phase: PracticePhase.recording));
    // 5분 도달, 전화 수신 등으로 녹음이 저절로 끝나도 결과를 낸다.
    unawaited(_recorder.finished.then(_finish, onError: (_) {}));
  }

  void _onFrames(Float32List frame) {
    _live.add(frame);
    _set(_state.copyWith(
      elapsed: Duration(
          microseconds:
              _live.length * Duration.microsecondsPerSecond ~/ recordSampleRate),
      livePitch: _live.points,
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

  Future<void> _finish(RecordResult r) =>
      _finishing ??= _finishRecording(r);

  Future<void> _finishRecording(RecordResult r) async {
    await _frameSub?.cancel();
    _frameSub = null;

    final expected = r.elapsed.inMicroseconds * recordSampleRate ~/
        Duration.microsecondsPerSecond;
    final List<PitchPoint> pitch;
    if (_live.length >= expected * 0.95 && _live.length > 0) {
      pitch = _live.points;
    } else {
      final path = r.wavPath;
      pitch = await Isolate.run(() => analyzePitch(readWav(path)));
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
    transcription = _transcribe(session);
  }

  Future<void> _transcribe(PracticeSession session) async {
    try {
      final t = await _transcriber.transcribe(
        session.audioPath,
        onProgress: (v) => _set(_state.copyWith(transcribeProgress: v)),
      );
      final marks = compareToScript(script.body, t.text);
      await _sessions.updateMarks(session.id!, marks, transcript: t.text);
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
