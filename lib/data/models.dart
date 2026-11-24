import 'dart:convert';

import '../analysis/compare.dart';
import '../analysis/pitch.dart';

/// 연습할 원고. v1은 사용자가 붙여넣은 원고만 있고 모두 무료다.
/// [category], [difficulty], [isPremium]은 나중에 넣을 내장 원고를 위한 칸이다.
class Script {
  const Script({
    this.id,
    required this.title,
    required this.body,
    this.category,
    this.difficulty,
    this.isPremium = false,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final String body;
  final String? category;
  final int? difficulty;
  final bool isPremium;
  final DateTime createdAt;
}

/// 한 번의 연습 기록.
class PracticeSession {
  const PracticeSession({
    this.id,
    required this.scriptId,
    required this.audioPath,
    required this.elapsed,
    required this.syllablesPerMinute,
    required this.pitch,
    this.marks,
    this.transcript,
    required this.createdAt,
  });

  final int? id;
  final int scriptId;
  final String audioPath;
  final Duration elapsed;
  final double syllablesPerMinute;
  final List<PitchPoint> pitch;

  /// 원고 비교 결과. 인식이 끝나기 전에는 null.
  final List<WordMark>? marks;

  /// 인식된 글. 인식이 끝나기 전에는 null.
  final String? transcript;
  final DateTime createdAt;
}

/// 메모 종류. 화면에는 [label]로 보인다.
enum MemoKind {
  pronunciation('발음'),
  speed('속도'),
  intonation('억양'),
  emphasis('강조');

  const MemoKind(this.label);
  final String label;
}

/// 원고 어절 하나에 붙인 메모.
class Memo {
  const Memo({
    this.id,
    required this.scriptId,
    required this.wordIndex,
    required this.kind,
    required this.text,
    required this.createdAt,
  });

  final int? id;
  final int scriptId;
  final int wordIndex;
  final MemoKind kind;
  final String text;
  final DateTime createdAt;
}

// JSON 열 변환. 음높이는 [밀리초, Hz|null] 쌍으로 짧게 저장한다.
String encodePitch(List<PitchPoint> pitch) =>
    jsonEncode([for (final p in pitch) [p.t.inMilliseconds, p.hz]]);

List<PitchPoint> decodePitch(String json) => [
      for (final e in jsonDecode(json) as List)
        PitchPoint(
          t: Duration(milliseconds: (e as List)[0] as int),
          hz: (e[1] as num?)?.toDouble(),
        ),
    ];

String encodeMarks(List<WordMark> marks) => jsonEncode([
      for (final m in marks)
        {'s': m.scriptWord, 'h': m.heardWord, 'st': m.status.name, 'sc': m.score},
    ]);

List<WordMark> decodeMarks(String json) => [
      for (final e in jsonDecode(json) as List)
        WordMark(
          scriptWord: (e as Map)['s'] as String,
          heardWord: e['h'] as String?,
          status: MarkStatus.values.byName(e['st'] as String),
          score: (e['sc'] as num?)?.toDouble(),
        ),
    ];
