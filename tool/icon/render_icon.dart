// 앱 아이콘 PNG를 그린다. 일반 테스트에 섞이지 않게 tool/ 아래에 둔다.
// 실행: flutter test tool/icon/render_icon.dart
// 결과: assets/icon/icon.png (배경 포함), assets/icon/icon_foreground.png (적응형 아이콘 앞면)
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _background = Color(0xFFF5F3EE); // 앱 바탕 (따뜻한 미색)
const _ink = Color(0xFF1B1B1B); // 녹음 버튼 검정
const _paper = Color(0xFFF5F3EE);
const _red = Color(0xFFE5483B); // ON AIR 빨강

/// [scale] 1.0이면 1024 캔버스를 꽉 채우는 크기, 적응형 앞면은 안전 영역(66%)에 맞게 줄인다.
void paintIcon(Canvas canvas, double size, {required bool background, double scale = 1}) {
  final c = Offset(size / 2, size / 2);
  final u = size / 1024 * scale; // 1024 기준 단위

  if (background) {
    canvas.drawRect(Offset.zero & Size(size, size), Paint()..color = _background);
  }

  // 녹음 버튼 같은 검은 원
  canvas.drawCircle(c, 360 * u, Paint()..color = _ink);

  // 마이크: 캡슐 머리 + U자 받침 + 기둥 + 받침대
  final stroke = Paint()
    ..color = _paper
    ..style = PaintingStyle.stroke
    ..strokeWidth = 30 * u
    ..strokeCap = StrokeCap.round;
  final head = RRect.fromRectAndRadius(
    Rect.fromCenter(center: c + Offset(0, -55 * u), width: 150 * u, height: 250 * u),
    Radius.circular(75 * u),
  );
  canvas.drawRRect(head, Paint()..color = _paper);
  // 머리의 결(가로줄) — 검은 선으로 살짝
  final grille = Paint()
    ..color = _ink
    ..strokeWidth = 10 * u
    ..strokeCap = StrokeCap.round;
  for (final dy in [-110.0, -70.0, -30.0]) {
    canvas.drawLine(c + Offset(-38 * u, dy * u), c + Offset(38 * u, dy * u), grille);
  }
  final cradle = Rect.fromCircle(center: c + Offset(0, -40 * u), radius: 128 * u);
  canvas.drawArc(cradle, 0.15, pi - 0.3, false, stroke);
  canvas.drawLine(c + Offset(0, 88 * u), c + Offset(0, 160 * u), stroke);
  canvas.drawLine(c + Offset(-70 * u, 170 * u), c + Offset(70 * u, 170 * u), stroke);

  // ON AIR 불빛 (빛 번짐 + 점)
  final light = c + Offset(205 * u, -215 * u);
  canvas.drawCircle(
      light,
      60 * u,
      Paint()
        ..color = _red.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 26 * u));
  canvas.drawCircle(light, 38 * u, Paint()..color = _red);
}

Future<void> _write(String path, {required bool background, double scale = 1}) async {
  const size = 1024.0;
  final recorder = ui.PictureRecorder();
  paintIcon(Canvas(recorder), size, background: background, scale: scale);
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('render app icon', () async {
    await _write('assets/icon/icon.png', background: true);
    // 적응형 아이콘은 런처가 모양을 잘라내므로 앞면을 안전 영역(약 66%) 안으로 줄인다.
    await _write('assets/icon/icon_foreground.png', background: false, scale: 0.72);
    expect(File('assets/icon/icon.png').lengthSync(), greaterThan(1000));
  });
}
