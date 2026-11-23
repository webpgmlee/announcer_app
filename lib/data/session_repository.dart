import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../analysis/compare.dart';
import 'models.dart';

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

  static Future<void> _deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
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
