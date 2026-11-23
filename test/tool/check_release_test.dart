import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_release.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('release_check');
    Directory('${root.path}/lib/screens').createSync(recursive: true);
    File('${root.path}/lib/main.dart').writeAsStringSync("void main() {}\n");
    File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: demo
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.4.6
dev_dependencies:
  flutter_test:
    sdk: flutter
''');
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('문제가 없으면 위반 없음', () {
    expect(findViolations(root), isEmpty);
  });

  test('금지 문구 "발음 점수", "발음 채점"을 찾는다', () {
    File('${root.path}/lib/screens/a.dart')
        .writeAsStringSync("const t = '당신의 발음 점수는';\nconst u = '발음 채점';\n");
    final v = findViolations(root);
    expect(v, hasLength(2));
    expect(v.first, contains('lib/screens/a.dart:1'));
    expect(v.first, contains('발음 점수'));
  });

  test('금지 패키지 import를 찾는다 (firebase, azure, http)', () {
    File('${root.path}/lib/screens/b.dart').writeAsStringSync('''
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:azure_speech/azure_speech.dart';
import 'package:http_parser/http_parser.dart';
''');
    final v = findViolations(root);
    expect(v.where((e) => e.contains('firebase_core')), hasLength(1));
    expect(v.where((e) => e.contains("package:http/")), hasLength(1));
    expect(v.where((e) => e.contains('azure_speech')), hasLength(1));
    expect(v.where((e) => e.contains('http_parser')), isEmpty);
  });

  test('pubspec 의존성의 금지 패키지를 찾는다', () {
    File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: demo
dependencies:
  flutter:
    sdk: flutter
  firebase_analytics: ^11.0.0
  http: ^1.2.0
dev_dependencies:
  flutter_test:
    sdk: flutter
''');
    final v = findViolations(root);
    expect(v.where((e) => e.contains('pubspec.yaml')), hasLength(2));
  });

  test('실제 저장소는 통과한다', () {
    expect(findViolations(Directory.current), isEmpty);
  });
}
