// 출시 전 점검. lib/와 pubspec.yaml에서 아래를 찾으면 실패한다.
// - 과장 문구: "발음 점수", "발음 채점" (스펙 4장: 할 수 없는 걸 하는 척하지 않는다)
// - 금지 패키지: firebase, azure, http (서버·분석 SDK 없음, B 기능 코드 미포함)
//
// 실행: dart run tool/check_release.dart
import 'dart:io';

const forbiddenPhrases = ['발음 점수', '발음 채점'];

bool isForbiddenPackage(String name) =>
    name.contains('firebase') || name.contains('azure') || name == 'http';

final _import = RegExp(r'''^\s*(?:import|export)\s+['"]package:([A-Za-z0-9_]+)/''');

List<String> findViolations(Directory root) {
  final out = <String>[];
  String rel(FileSystemEntity e) =>
      e.path.substring(root.path.length + 1).replaceAll(r'\', '/');

  final lib = Directory('${root.path}/lib');
  if (lib.existsSync()) {
    final files = lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final phrase in forbiddenPhrases) {
          if (lines[i].contains(phrase)) {
            out.add('${rel(f)}:${i + 1}: 금지 문구 "$phrase"');
          }
        }
        final m = _import.firstMatch(lines[i]);
        if (m != null && isForbiddenPackage(m[1]!)) {
          out.add('${rel(f)}:${i + 1}: 금지 패키지 package:${m[1]}/');
        }
      }
    }
  }

  final pubspec = File('${root.path}/pubspec.yaml');
  if (pubspec.existsSync()) {
    var inDeps = false;
    final lines = pubspec.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (RegExp(r'^\S').hasMatch(line)) {
        inDeps = line.startsWith('dependencies:') ||
            line.startsWith('dev_dependencies:') ||
            line.startsWith('dependency_overrides:');
        continue;
      }
      final dep = RegExp(r'^  ([A-Za-z0-9_]+)\s*:').firstMatch(line);
      if (inDeps && dep != null && isForbiddenPackage(dep[1]!)) {
        out.add('pubspec.yaml:${i + 1}: 금지 패키지 ${dep[1]}');
      }
    }
  }

  // 다른 패키지가 끌고 들어온 firebase·azure도 막는다 (http는 간접 의존이 흔해 제외).
  final lock = File('${root.path}/pubspec.lock');
  if (lock.existsSync()) {
    final lines = lock.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final m = RegExp(r'^  ([A-Za-z0-9_]+):$').firstMatch(lines[i]);
      if (m != null && (m[1]!.contains('firebase') || m[1]!.contains('azure'))) {
        out.add('pubspec.lock:${i + 1}: 금지 패키지(간접 의존) ${m[1]}');
      }
    }
  }
  return out;
}

void main() {
  final violations = findViolations(Directory.current);
  if (violations.isEmpty) {
    stdout.writeln('출시 점검 통과');
    return;
  }
  stderr.writeln('출시 점검 실패:');
  violations.forEach(stderr.writeln);
  exitCode = 1;
}
