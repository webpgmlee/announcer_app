import 'package:just_audio/just_audio.dart';

abstract class Player {
  Future<void> play(String path);
  Future<void> pause();
  Stream<Duration> get position;
  Stream<bool> get playing;
  Future<void> dispose();
}

class JustAudioPlayer implements Player {
  final _player = AudioPlayer();
  String? _loaded;

  @override
  Future<void> play(String path) async {
    if (_loaded != path) {
      await _player.setFilePath(path);
      _loaded = path;
    } else if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    // play()는 재생이 끝날 때 완료되므로 기다리지 않는다.
    _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<bool> get playing => _player.playingStream;

  @override
  Future<void> dispose() => _player.dispose();
}
