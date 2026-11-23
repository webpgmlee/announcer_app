// Task 1 시험용 코드. 엔진 확정 후 삭제한다.
//
// 실행: flutter run --release -t spike/whisper_spike.dart
// 폰에 미리 넣을 파일 (adb push):
//   /sdcard/Android/data/kr.tg.announcer_app/files/
//     news.wav            16kHz 모노 PCM16, 약 1분 한국어 뉴스 낭독
//     script.txt          그 낭독의 원고 (UTF-8)
//     ggml-base-q5_1.bin  ggml-small-q5_1.bin  (양자화 모델)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

void main() => runApp(const MaterialApp(home: SpikePage()));

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});
  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  final _log = StringBuffer();
  bool _busy = false;

  void _say(String s) {
    debugPrint('[SPIKE] $s');
    setState(() => _log.writeln(s));
  }

  Future<void> _run(String quantFile, WhisperModel slot) async {
    setState(() => _busy = true);
    try {
      final ext = (await getExternalStorageDirectory())!.path;
      // 폰에 넣은 파일이 없으면 APK에 든 샘플(TTS 낭독)을 꺼내 쓴다.
      final bundled = ['news.wav', 'script.txt', if (quantFile == 'ggml-base-q5_1.bin') quantFile];
      for (final name in bundled) {
        final f = File('$ext/$name');
        if (!f.existsSync()) {
          final data = await rootBundle.load('spike/assets/$name');
          await f.writeAsBytes(data.buffer.asUint8List());
          _say('$name: APK 샘플 사용');
        }
      }
      final wav = '$ext/news.wav';
      final script = await File('$ext/script.txt').readAsString();
      // whisper_ggml은 <지원폴더>/ggml-<이름>.bin 만 읽으므로 양자화 파일을 그 이름으로 복사한다.
      final controller = WhisperController();
      final target = await controller.getPath(slot);
      await File('$ext/$quantFile').copy(target);

      _say('== $quantFile ==');
      final sw = Stopwatch()..start();
      final result = await controller.transcribe(
        model: slot,
        audioPath: wav,
        lang: 'ko',
        maxContext: 0,
        suppressNonSpeechTokens: true,
      );
      sw.stop();
      final text = result?.transcription.text ?? '(실패)';
      _say('시간: ${sw.elapsed.inMilliseconds / 1000}초');
      _say('단어 일치율: ${(wordAccuracy(script, text) * 100).toStringAsFixed(1)}%');
      _say('인식: $text');
    } catch (e) {
      _say('오류: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Whisper spike')),
        body: Column(children: [
          Wrap(spacing: 8, children: [
            ElevatedButton(
                onPressed: _busy ? null : () => _run('ggml-base-q5_1.bin', WhisperModel.base),
                child: const Text('base')),
            ElevatedButton(
                onPressed: _busy ? null : () => _run('ggml-small-q5_1.bin', WhisperModel.small),
                child: const Text('small')),
          ]),
          if (_busy) const LinearProgressIndicator(),
          Expanded(child: SingleChildScrollView(child: SelectableText(_log.toString()))),
        ]),
      );
}

/// 원고 어절 기준 일치율 = 1 - (어절 편집 거리 / 원고 어절 수).
double wordAccuracy(String script, String heard) {
  List<String> words(String s) => s
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final a = words(script), b = words(heard);
  if (a.isEmpty) return 0;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final sub = prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      cur[j] = [sub, prev[j] + 1, cur[j - 1] + 1].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  final acc = 1 - prev[b.length] / a.length;
  return acc < 0 ? 0 : acc;
}
