import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:announcer_app/audio/wav.dart';
import 'package:announcer_app/speech/transcriber.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 조각마다 "조각N" 한 단어(0.2~0.8초)를 돌려주는 가짜 엔진.
class FakeEngine implements ChunkEngine {
  final received = <Duration>[];
  final paths = <String>[];

  @override
  Future<Transcript> transcribeChunk(String wavPath,
      {void Function(double progress)? onProgress}) async {
    paths.add(wavPath);
    final samples = readWav(wavPath);
    received.add(Duration(milliseconds: samples.length * 1000 ~/ 16000));
    final n = received.length - 1;
    return Transcript(text: '조각$n', words: [
      TimedWord(
          word: '조각$n',
          start: const Duration(milliseconds: 200),
          end: const Duration(milliseconds: 800)),
    ]);
  }
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('stt_test'));
  tearDown(() => dir.delete(recursive: true));

  String wav(String name, Duration d, {bool silent = false}) {
    final n = 16000 * d.inMilliseconds ~/ 1000;
    final samples = Float32List.fromList(List.generate(
        n, (i) => silent ? 0.0 : 0.3 * sin(2 * pi * 180 * i / 16000)));
    final path = p.join(dir.path, name);
    writeWav(path, samples);
    return path;
  }

  test('75초 WAV를 30초 단위 3조각으로 나누고 단어 시간을 밀어 붙인다', () async {
    final engine = FakeEngine();
    final t = ChunkedTranscriber(engine, tempDirectory: dir);
    final progress = <double>[];
    final result = await t.transcribe(wav('long.wav', const Duration(seconds: 75)),
        onProgress: progress.add);

    expect(engine.received, const [
      Duration(seconds: 30),
      Duration(seconds: 30),
      Duration(seconds: 15),
    ]);
    expect(result.text, '조각0 조각1 조각2');
    expect(result.words.map((w) => w.start), const [
      Duration(milliseconds: 200),
      Duration(seconds: 30, milliseconds: 200),
      Duration(seconds: 60, milliseconds: 200),
    ]);
    expect(result.words.last.end, const Duration(seconds: 60, milliseconds: 800));

    expect(progress.first, 0);
    expect(progress.last, 1);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThan(progress[i - 1]));
    }
  });

  test('조각 임시 파일은 끝나면 지운다', () async {
    final engine = FakeEngine();
    await ChunkedTranscriber(engine, tempDirectory: dir)
        .transcribe(wav('a.wav', const Duration(seconds: 40)));
    expect(engine.paths, hasLength(2));
    for (final path in engine.paths) {
      expect(File(path).existsSync(), isFalse);
    }
  });

  test('무음 WAV는 빈 Transcript (엔진을 부르지 않는다)', () async {
    final engine = FakeEngine();
    final progress = <double>[];
    final result = await ChunkedTranscriber(engine, tempDirectory: dir).transcribe(
        wav('silent.wav', const Duration(seconds: 10), silent: true),
        onProgress: progress.add);
    expect(result.text, isEmpty);
    expect(result.words, isEmpty);
    expect(engine.received, isEmpty);
    expect(progress.last, 1);
  });

  test('중간의 무음 조각은 건너뛰고 시간은 그대로 맞춘다', () async {
    final speech = Float32List.fromList(
        List.generate(16000 * 30, (i) => 0.3 * sin(2 * pi * 180 * i / 16000)));
    final samples = Float32List(16000 * 90)
      ..setRange(0, speech.length, speech)
      ..setRange(16000 * 60, 16000 * 90, speech);
    final path = p.join(dir.path, 'gap.wav');
    writeWav(path, samples);

    final engine = FakeEngine();
    final result =
        await ChunkedTranscriber(engine, tempDirectory: dir).transcribe(path);
    expect(engine.received, hasLength(2));
    expect(result.words.map((w) => w.start.inSeconds), [0, 60]);
  });

  test('빈 WAV(0초)도 죽지 않는다', () async {
    final path = p.join(dir.path, 'empty.wav');
    writeWav(path, Float32List(0));
    final result =
        await ChunkedTranscriber(FakeEngine(), tempDirectory: dir).transcribe(path);
    expect(result.text, isEmpty);
  });

  test('writeWav/readWav 왕복', () {
    final path = p.join(dir.path, 'rt.wav');
    writeWav(path, Float32List.fromList([0, 0.5, -0.5, 0.25]));
    final back = readWav(path);
    expect(back, hasLength(4));
    expect(back[1], closeTo(0.5, 1e-4));
    expect(back[2], closeTo(-0.5, 1e-4));
  });
}
