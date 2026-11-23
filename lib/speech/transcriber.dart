import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../audio/wav.dart';

class TimedWord {
  const TimedWord({required this.word, required this.start, required this.end});
  final String word;
  final Duration start;
  final Duration end;
}

class Transcript {
  const Transcript({required this.text, required this.words});
  static const empty = Transcript(text: '', words: []);
  final String text;
  final List<TimedWord> words;
}

abstract class Transcriber {
  /// [onProgress]는 0에서 1까지 늘어난다.
  Future<Transcript> transcribe(String wavPath,
      {void Function(double progress)? onProgress});
}

/// 30초 이하 WAV 한 조각을 인식하는 엔진. 실제로는 Whisper, 테스트에서는 가짜.
abstract class ChunkEngine {
  Future<Transcript> transcribeChunk(String wavPath,
      {void Function(double progress)? onProgress});
}

/// 모델이 처리하는 단위(30초)로 녹음을 나눠 인식하고 이어 붙인다.
const chunkLength = Duration(seconds: 30);

/// 이보다 조용한 조각은 인식하지 않는다 (무음에서 엉뚱한 글이 나오는 것 방지).
const silentChunkRms = 0.01;

class ChunkedTranscriber implements Transcriber {
  ChunkedTranscriber(this._engine, {Directory? tempDirectory})
      : _temp = tempDirectory;
  final ChunkEngine _engine;
  final Directory? _temp;

  @override
  Future<Transcript> transcribe(String wavPath,
      {void Function(double progress)? onProgress}) async {
    var last = -1.0;
    void report(double v) {
      if (v > last) {
        last = v;
        onProgress?.call(v);
      }
    }

    report(0);
    final samples = readWav(wavPath);
    final per = recordSampleRate * chunkLength.inSeconds;
    final count = (samples.length / per).ceil();
    final texts = <String>[];
    final words = <TimedWord>[];
    final temp = _temp ?? Directory.systemTemp;

    for (var i = 0; i < count; i++) {
      final from = i * per;
      final to = (from + per).clamp(0, samples.length);
      if (rms(samples, from, to) >= silentChunkRms) {
        final path = p.join(temp.path,
            'chunk_${DateTime.now().microsecondsSinceEpoch}_$i.wav');
        writeWav(path, Float32List.sublistView(samples, from, to));
        try {
          final part = await _engine.transcribeChunk(path,
              onProgress: (v) => report((i + v.clamp(0, 0.99)) / count));
          final offset = chunkLength * i;
          if (part.text.trim().isNotEmpty) texts.add(part.text.trim());
          words.addAll(part.words.map((w) => TimedWord(
              word: w.word, start: w.start + offset, end: w.end + offset)));
        } finally {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
        }
      }
      report((i + 1) / count);
    }
    report(1);
    return texts.isEmpty && words.isEmpty
        ? Transcript.empty
        : Transcript(text: texts.join(' '), words: words);
  }
}
