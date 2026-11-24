import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:whisper_ggml/whisper_ggml.dart';

import 'whisper_transcriber.dart';

/// 녹음하는 동안 도는 실시간 인식 세션.
abstract class LiveSession {
  /// 16kHz 모노 little-endian PCM16 바이트를 넣는다.
  void feed(Uint8List pcm16);

  /// 지금까지 들린 전체 글 (매번 앞의 글을 대신한다).
  Stream<String> get partials;

  /// 남은 소리를 인식하고 세션을 닫는다. 최종 글을 돌려준다.
  Future<String> stop();
}

abstract class LiveTranscriber {
  Future<LiveSession> start();
}

/// whisper_ggml 실시간 세션. 인식은 별도 워커 isolate에서 돈다. 한 번에 하나만 열 수 있다.
class WhisperLiveTranscriber implements LiveTranscriber {
  final _controller = WhisperController();

  @override
  Future<LiveSession> start() async {
    final target = File(await _controller.getPath(WhisperModel.base));
    await ensureModelFile(target, () => rootBundle.load(modelAsset), version: modelAsset);
    final session = await startWhisperLiveSession(
      modelPath: target.path,
      lang: 'ko',
      suppressNonSpeechTokens: true,
      keepModelLoaded: true,
    );
    return _WhisperLive(session);
  }
}

class _WhisperLive implements LiveSession {
  _WhisperLive(this._s);
  final WhisperLiveSession _s;

  @override
  void feed(Uint8List pcm16) => _s.feed(pcm16);

  @override
  Stream<String> get partials => _s.partials;

  @override
  Future<String> stop() => _s.stop();
}
