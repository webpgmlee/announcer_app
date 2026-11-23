import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import '../data/session_repository.dart';
import 'wav.dart';

export 'wav.dart' show recordSampleRate;

/// 녹음 1회 최대 길이 (스펙 2장).
const maxRecordDuration = Duration(minutes: 5);

enum RecordStart { ok, permissionDenied }

class RecordResult {
  const RecordResult({
    required this.wavPath,
    required this.elapsed,
    required this.interrupted,
  });
  final String wavPath;
  final Duration elapsed;

  /// 전화 수신, 앱 백그라운드 전환 등으로 녹음이 끊겼으면 true.
  final bool interrupted;
}

abstract class Recorder {
  Future<RecordStart> start();

  /// 녹음 중 -1~1 범위 샘플을 실시간으로 흘려보낸다 (억양 선용).
  Stream<Float32List> get pcmFrames;
  Future<RecordResult> stop();

  /// 녹음이 어떤 이유로든(정지, 5분 도달, 끊김) 끝나면 완료된다.
  Future<RecordResult> get finished;
}

/// 마이크 PCM16 바이트를 내주는 쪽. 테스트에서는 가짜로 바꾼다.
abstract class PcmSource {
  Future<bool> hasPermission();
  Future<Stream<Uint8List>> start();
  Future<void> stop();

  /// 오디오 세션이 끊길 때마다 알린다.
  Stream<void> get interruptions;
}

class StreamRecorder implements Recorder {
  StreamRecorder(
    this._source, {
    this._directory,
    this.maxDuration = maxRecordDuration,
  });

  final PcmSource _source;
  final Directory? _directory;
  final Duration maxDuration;
  final _frames = StreamController<Float32List>.broadcast();

  bool _active = false;
  RandomAccessFile? _file;
  String? _path;
  int _samples = 0;
  int? _carry;
  StreamSubscription<Uint8List>? _pcmSub;
  StreamSubscription<void>? _intSub;
  Completer<RecordResult>? _done;
  Future<RecordResult>? _finishing;

  int get _maxSamples =>
      maxDuration.inMicroseconds * recordSampleRate ~/ Duration.microsecondsPerSecond;

  @override
  Stream<Float32List> get pcmFrames => _frames.stream;

  @override
  Future<RecordResult> get finished {
    final done = _done;
    if (done == null) throw StateError('녹음을 시작하지 않았어요');
    return done.future;
  }

  @override
  Future<RecordStart> start() async {
    if (_active) throw StateError('이미 녹음 중이에요');
    if (!await _source.hasPermission()) return RecordStart.permissionDenied;

    final dir = _directory ?? await SessionRepository.recordingsDirectory();
    final path = p.join(dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.wav');
    _file = File(path).openSync(mode: FileMode.write)..writeFromSync(Uint8List(44));
    _path = path;
    _samples = 0;
    _carry = null;
    _finishing = null;
    _done = Completer<RecordResult>();
    _active = true;

    final stream = await _source.start();
    _pcmSub = stream.listen(
      _onData,
      onDone: () => _finish(interrupted: true),
      onError: (Object _) => _finish(interrupted: true),
    );
    _intSub = _source.interruptions.listen((_) => _finish(interrupted: true));
    return RecordStart.ok;
  }

  void _onData(Uint8List chunk) {
    if (!_active) return;
    var bytes = chunk;
    if (_carry != null) {
      bytes = Uint8List(chunk.length + 1)
        ..[0] = _carry!
        ..setRange(1, chunk.length + 1, chunk);
      _carry = null;
    }
    final available = bytes.length ~/ 2;
    final take = available.clamp(0, _maxSamples - _samples);
    if (take > 0) {
      _file!.writeFromSync(bytes, 0, take * 2);
      final view = ByteData.sublistView(bytes);
      final floats = Float32List(take);
      for (var i = 0; i < take; i++) {
        floats[i] = view.getInt16(i * 2, Endian.little) / 32768;
      }
      _samples += take;
      _frames.add(floats);
    }
    if (take == available && bytes.length.isOdd) _carry = bytes.last;
    if (_samples >= _maxSamples) _finish(interrupted: false);
  }

  @override
  Future<RecordResult> stop() {
    if (_active) return _finish(interrupted: false);
    return _finishing ?? finished;
  }

  Future<RecordResult> _finish({required bool interrupted}) {
    if (!_active) return _finishing ?? finished;
    _active = false;
    return _finishing = () async {
      await _pcmSub?.cancel();
      await _intSub?.cancel();
      try {
        await _source.stop();
      } catch (_) {
        // 이미 멈춘 마이크를 다시 멈추려다 난 오류는 무시한다.
      }
      final file = _file!;
      file.setPositionSync(0);
      file.writeFromSync(wavHeader(_samples * 2));
      file.closeSync();
      final result = RecordResult(
        wavPath: _path!,
        elapsed: Duration(
            microseconds: _samples * Duration.microsecondsPerSecond ~/ recordSampleRate),
        interrupted: interrupted,
      );
      _done!.complete(result);
      return result;
    }();
  }
}

/// 실제 마이크. `record` 패키지의 스트림 녹음을 쓴다.
/// 다른 앱이 오디오를 가져가거나(전화 수신) 앱이 백그라운드로 가면 끊김으로 알린다.
class RecordPcmSource with WidgetsBindingObserver implements PcmSource {
  final _recorder = AudioRecorder();
  final _interruptions = StreamController<void>.broadcast();
  StreamSubscription<RecordState>? _stateSub;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> start() async {
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: recordSampleRate,
      numChannels: 1,
    ));
    _stateSub = _recorder.onStateChanged().listen((s) {
      if (s == RecordState.pause) _interruptions.add(null);
    });
    WidgetsBinding.instance.addObserver(this);
    return stream;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _interruptions.add(null);
    }
  }

  @override
  Future<void> stop() async {
    WidgetsBinding.instance.removeObserver(this);
    await _stateSub?.cancel();
    await _recorder.stop();
  }

  @override
  Stream<void> get interruptions => _interruptions.stream;
}
