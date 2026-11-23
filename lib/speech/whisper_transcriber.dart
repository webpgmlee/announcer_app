import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:whisper_ggml/whisper_ggml.dart';

import 'transcriber.dart';

/// 앱에 넣은 모델 파일 (docs/decisions/speech-engine.md).
/// 모델은 git에 넣지 않으므로 빌드 전에 assets/models/에 받아 둔다 (README 참고).
const modelAsset = 'assets/models/ggml-base-q5_1.bin';

/// whisper_ggml은 <지원폴더>/ggml-<이름>.bin만 읽으므로 이 슬롯 이름으로 복사한다.
const _modelSlot = WhisperModel.base;

class TranscriptionException implements Exception {
  const TranscriptionException(this.message);
  final String message;
  @override
  String toString() => 'TranscriptionException: $message';
}

/// 폰 안에서 Whisper로 인식한다. 언어는 한국어(ko)로 고정한다.
/// 인식은 whisper_ggml이 별도 isolate(Isolate.run)에서 돌려 화면이 멈추지 않는다.
class WhisperTranscriber implements Transcriber {
  WhisperTranscriber() : _inner = ChunkedTranscriber(WhisperChunkEngine());
  final ChunkedTranscriber _inner;

  @override
  Future<Transcript> transcribe(String wavPath,
          {void Function(double progress)? onProgress}) =>
      _inner.transcribe(wavPath, onProgress: onProgress);
}

class WhisperChunkEngine implements ChunkEngine {
  final _controller = WhisperController();
  Future<void>? _modelReady;

  /// 앱에 든 모델을 처음 한 번 지원 폴더로 꺼낸다.
  Future<void> _ensureModel() => _modelReady ??= () async {
        final target = File(await _controller.getPath(_modelSlot));
        final data = await rootBundle.load(modelAsset);
        if (target.existsSync() && target.lengthSync() == data.lengthInBytes) return;
        await target.parent.create(recursive: true);
        await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }();

  @override
  Future<Transcript> transcribeChunk(String wavPath,
      {void Function(double progress)? onProgress}) async {
    try {
      await _ensureModel();
    } catch (e) {
      _modelReady = null;
      throw TranscriptionException('음성 인식 모델을 준비하지 못했어요: $e');
    }
    final result = await _controller.transcribe(
      model: _modelSlot,
      audioPath: wavPath,
      lang: 'ko',
      withSegments: true,
      splitOnWord: true,
      maxContext: 0,
      suppressNonSpeechTokens: true,
      keepModelLoaded: true,
      onProgress: onProgress == null ? null : (percent) => onProgress(percent / 100),
    );
    if (result == null) {
      throw const TranscriptionException('음성 인식에 실패했어요');
    }
    final r = result.transcription;
    return Transcript(
      text: r.text.trim(),
      words: [
        for (final s in r.segments ?? const <WhisperTranscribeSegment>[])
          if (s.text.trim().isNotEmpty)
            TimedWord(word: s.text.trim(), start: s.fromTs, end: s.toTs),
      ],
    );
  }
}
