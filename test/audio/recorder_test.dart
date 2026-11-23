import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:announcer_app/audio/recorder.dart';
import 'package:flutter_test/flutter_test.dart';

/// 마이크 대신 쓰는 가짜 PCM 소스.
class FakePcmSource implements PcmSource {
  FakePcmSource({this.permission = true});
  bool permission;
  StreamController<Uint8List>? _pcm;
  final _interruptions = StreamController<void>.broadcast();
  bool stopped = false;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<Stream<Uint8List>> start() async {
    _pcm = StreamController<Uint8List>();
    return _pcm!.stream;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    await _pcm?.close();
  }

  @override
  Stream<void> get interruptions => _interruptions.stream;

  /// 16kHz PCM16 [seconds]초 분량을 보낸다 (값은 작은 톱니파).
  void feedSeconds(double seconds, {int chunk = 3200}) {
    final bytes = (16000 * seconds).round() * 2;
    final data = Uint8List(bytes);
    final view = ByteData.sublistView(data);
    for (var i = 0; i < bytes ~/ 2; i++) {
      view.setInt16(i * 2, (i % 100) * 100, Endian.little);
    }
    for (var o = 0; o < bytes; o += chunk) {
      _pcm!.add(Uint8List.sublistView(data, o, (o + chunk).clamp(0, bytes)));
    }
  }

  void interrupt() => _interruptions.add(null);
}

int wavDataSize(File f) =>
    ByteData.sublistView(f.readAsBytesSync()).getUint32(40, Endian.little);

void main() {
  late Directory dir;
  late FakePcmSource source;
  late StreamRecorder recorder;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rec_test');
    source = FakePcmSource();
    recorder = StreamRecorder(source, directory: dir);
  });
  tearDown(() => dir.delete(recursive: true));

  test('녹음 → 정지하면 16kHz 모노 PCM16 WAV와 걸린 시간', () async {
    expect(await recorder.start(), RecordStart.ok);
    source.feedSeconds(2);
    await pumpEventQueue();
    final r = await recorder.stop();
    expect(r.interrupted, isFalse);
    expect(r.elapsed, const Duration(seconds: 2));
    final f = File(r.wavPath);
    final bytes = f.readAsBytesSync();
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    final h = ByteData.sublistView(bytes);
    expect(h.getUint16(22, Endian.little), 1); // 모노
    expect(h.getUint32(24, Endian.little), 16000);
    expect(h.getUint16(34, Endian.little), 16);
    expect(wavDataSize(f), 64000);
    expect(bytes.length, 44 + 64000);
  });

  test('pcmFrames로 -1~1 범위 샘플이 실시간으로 흐른다', () async {
    final frames = <Float32List>[];
    recorder.pcmFrames.listen(frames.add);
    await recorder.start();
    source.feedSeconds(0.5);
    await pumpEventQueue();
    final total = frames.fold<int>(0, (n, f) => n + f.length);
    expect(total, 8000);
    expect(frames.expand((f) => f).every((v) => v >= -1 && v <= 1), isTrue);
    await recorder.stop();
  });

  test('5분이 지나면 자동 정지 (elapsed == 5분)', () async {
    await recorder.start();
    source.feedSeconds(5 * 60 + 3, chunk: 32000);
    final r = await recorder.finished.timeout(const Duration(seconds: 10));
    expect(r.elapsed, const Duration(minutes: 5));
    expect(r.interrupted, isFalse);
    expect(source.stopped, isTrue);
    expect(wavDataSize(File(r.wavPath)), 5 * 60 * 16000 * 2);
    // 이미 멈춘 뒤 stop()을 불러도 같은 결과
    expect((await recorder.stop()).wavPath, r.wavPath);
  });

  test('권한 거부 시 permissionDenied, 파일을 만들지 않는다 (Review Focus 3)', () async {
    source.permission = false;
    expect(await recorder.start(), RecordStart.permissionDenied);
    expect(dir.listSync(), isEmpty);
  });

  test('오디오 세션이 끊기면 interrupted이고 그때까지 WAV가 남는다 (Review Focus 2)', () async {
    await recorder.start();
    source.feedSeconds(1);
    await pumpEventQueue();
    source.interrupt();
    final r = await recorder.finished.timeout(const Duration(seconds: 5));
    expect(r.interrupted, isTrue);
    expect(r.elapsed, const Duration(seconds: 1));
    expect(File(r.wavPath).existsSync(), isTrue);
    expect(wavDataSize(File(r.wavPath)), 32000);
  });

  test('홀수 바이트 조각도 샘플이 깨지지 않는다', () async {
    await recorder.start();
    source.feedSeconds(1, chunk: 3333);
    await pumpEventQueue();
    final r = await recorder.stop();
    expect(r.elapsed, const Duration(seconds: 1));
    expect(wavDataSize(File(r.wavPath)), 32000);
  });

  test('아무 소리도 안 들어온 채 정지해도 죽지 않는다', () async {
    await recorder.start();
    final r = await recorder.stop();
    expect(r.elapsed, Duration.zero);
    expect(wavDataSize(File(r.wavPath)), 0);
  });
}
