import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../analysis/compare.dart';
import 'models.dart';
import 'practice_state.dart';

class SessionRepository {
  SessionRepository(this._db);
  final Database _db;

  /// 녹음 파일을 두는 폴더: 앱 문서 폴더의 recordings/
  static Future<Directory> recordingsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'recordings')).create(recursive: true);
  }

  Future<int> add(PracticeSession s) => _db.insert('sessions', {
        'script_id': s.scriptId,
        'audio_path': s.audioPath,
        'elapsed_ms': s.elapsed.inMilliseconds,
        'spm': s.syllablesPerMinute,
        'pitch_json': encodePitch(s.pitch),
        'marks_json': s.marks == null ? null : encodeMarks(s.marks!),
        'transcript': s.transcript,
        'created_at': s.createdAt.millisecondsSinceEpoch,
      });

  Future<void> updateMarks(int id, List<WordMark> marks, {String? transcript}) =>
      _db.update(
        'sessions',
        {
          'marks_json': encodeMarks(marks),
          'transcript': ?transcript,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<List<PracticeSession>> forScript(int scriptId) async {
    final rows = await _db.query('sessions',
        where: 'script_id = ?',
        whereArgs: [scriptId],
        orderBy: 'created_at DESC, id DESC');
    return rows.map(_fromRow).toList();
  }

  /// 원고별 녹음 횟수와 마지막 녹음 시각. 녹음이 없는 원고는 들어 있지 않다.
  Future<Map<int, PracticeStat>> practiceStats() async {
    final rows = await _db.rawQuery(
        'SELECT script_id, COUNT(*) AS n, MAX(created_at) AS last FROM sessions GROUP BY script_id');
    return {
      for (final r in rows)
        r['script_id'] as int: (
          count: r['n'] as int,
          last: DateTime.fromMillisecondsSinceEpoch(r['last'] as int),
        ),
    };
  }

  /// 모든 원고의 녹음 기록, 최신순.
  Future<List<PracticeSession>> all() async {
    final rows = await _db.query('sessions', orderBy: 'created_at DESC, id DESC');
    return rows.map(_fromRow).toList();
  }

  /// 기록과 오디오 파일을 함께 지운다.
  Future<void> delete(int id) async {
    final rows = await _db.query('sessions',
        columns: ['audio_path'], where: 'id = ?', whereArgs: [id]);
    await _db.delete('sessions', where: 'id = ?', whereArgs: [id]);
    for (final r in rows) {
      await _deleteFile(r['audio_path'] as String);
    }
  }

  /// 원고 하나의 기록과 오디오를 모두 지운다.
  Future<void> deleteForScript(int scriptId) async {
    for (final s in await forScript(scriptId)) {
      await delete(s.id!);
    }
  }

  /// 파일 하나 지우기는 짧으므로 동기로 처리해, 목록이 갱신되기 전에 확실히 지운다.
  static Future<void> _deleteFile(String path) async {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  }

  static PracticeSession _fromRow(Map<String, Object?> r) => PracticeSession(
        id: r['id'] as int,
        scriptId: r['script_id'] as int,
        audioPath: r['audio_path'] as String,
        elapsed: Duration(milliseconds: r['elapsed_ms'] as int),
        syllablesPerMinute: (r['spm'] as num).toDouble(),
        pitch: decodePitch(r['pitch_json'] as String),
        marks: r['marks_json'] == null
            ? null
            : decodeMarks(r['marks_json'] as String),
        transcript: r['transcript'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      );
}
