import 'dart:io';
import 'dart:typed_data';

/// 녹음 형식: 16kHz, 모노, PCM16 WAV (Whisper 입력과 같다).
const recordSampleRate = 16000;

/// 16kHz 모노 PCM16 WAV 헤더(44바이트).
Uint8List wavHeader(int dataBytes) {
  final h = ByteData(44);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      h.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  h.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  h.setUint32(16, 16, Endian.little);
  h.setUint16(20, 1, Endian.little); // PCM
  h.setUint16(22, 1, Endian.little); // 모노
  h.setUint32(24, recordSampleRate, Endian.little);
  h.setUint32(28, recordSampleRate * 2, Endian.little);
  h.setUint16(32, 2, Endian.little);
  h.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  h.setUint32(40, dataBytes, Endian.little);
  return h.buffer.asUint8List();
}

/// -1~1 범위 샘플을 16kHz 모노 PCM16 WAV로 쓴다.
void writeWav(String path, Float32List samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(i * 2, v, Endian.little);
  }
  File(path)
    ..writeAsBytesSync(wavHeader(data.lengthInBytes))
    ..writeAsBytesSync(data.buffer.asUint8List(), mode: FileMode.append);
}

/// 16kHz 모노 PCM16 WAV를 -1~1 범위 샘플로 읽는다.
/// 녹음이 갑자기 끊겨 data 크기가 비어 있어도 남은 바이트를 모두 읽는다.
Float32List readWav(String path) {
  final bytes = File(path).readAsBytesSync();
  final view = ByteData.sublistView(bytes);
  var offset = 12;
  var dataStart = -1, dataSize = 0;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes, offset, offset + 4);
    final size = view.getUint32(offset + 4, Endian.little);
    if (id == 'data') {
      dataStart = offset + 8;
      dataSize = size;
      break;
    }
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  if (dataStart < 0) return Float32List(0);
  final available = bytes.length - dataStart;
  if (dataSize == 0 || dataSize > available) dataSize = available;
  final n = dataSize ~/ 2;
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = view.getInt16(dataStart + i * 2, Endian.little) / 32768;
  }
  return out;
}

/// 샘플의 RMS(소리 크기). 빈 입력은 0.
double rms(Float32List samples, [int start = 0, int? end]) {
  end ??= samples.length;
  if (end <= start) return 0;
  var sum = 0.0;
  for (var i = start; i < end; i++) {
    sum += samples[i] * samples[i];
  }
  return _sqrt(sum / (end - start));
}

double _sqrt(double x) {
  if (x <= 0) return 0;
  var r = x;
  for (var i = 0; i < 30; i++) {
    r = 0.5 * (r + x / r);
  }
  return r;
}
