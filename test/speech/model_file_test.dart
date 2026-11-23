import 'dart:io';
import 'dart:typed_data';

import 'package:announcer_app/speech/whisper_transcriber.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late File target;
  var loads = 0;
  Future<ByteData> load() async {
    loads++;
    return ByteData.sublistView(Uint8List.fromList(List.filled(1000, 7)));
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('model_test');
    target = File('${dir.path}/ggml-base.bin');
    loads = 0;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('처음에는 모델을 꺼내 쓴다', () async {
    await ensureModelFile(target, load, version: 'base-q5_1');
    expect(loads, 1);
    expect(target.lengthSync(), 1000);
  });

  test('이미 꺼낸 모델은 다시 읽지 않는다 (57MB를 매번 메모리에 올리지 않음)', () async {
    await ensureModelFile(target, load, version: 'base-q5_1');
    await ensureModelFile(target, load, version: 'base-q5_1');
    expect(loads, 1);
  });

  test('파일이 잘렸거나 모델 종류가 바뀌면 다시 꺼낸다', () async {
    await ensureModelFile(target, load, version: 'base-q5_1');
    target.writeAsBytesSync([1, 2, 3]);
    await ensureModelFile(target, load, version: 'base-q5_1');
    expect(loads, 2);
    expect(target.lengthSync(), 1000);
    await ensureModelFile(target, load, version: 'small-q5_1');
    expect(loads, 3);
  });
}
