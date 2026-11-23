import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:announcer_app/analysis/compare.dart';
import 'package:announcer_app/audio/recorder.dart';
import 'package:announcer_app/audio/wav.dart';
import 'package:announcer_app/data/database.dart';
import 'package:announcer_app/data/models.dart';
import 'package:announcer_app/data/session_repository.dart';
import 'package:announcer_app/practice/practice_controller.dart';
import 'package:announcer_app/speech/transcriber.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeRecorder implements Recorder {
  RecordStart startResult = RecordStart.ok;
  final frames = StreamController<Float32List>.broadcast();
  Completer<RecordResult> done = Completer();
  RecordResult? result;
  int starts = 0;

  @override
  Future<RecordStart> start() async {
    starts++;
    if (startResult == RecordStart.ok) done = Completer();
    return startResult;
  }

  @override
  Stream<Float32List> get pcmFrames => frames.stream;

  @override
  Future<RecordResult> stop() async {
    if (!done.isCompleted) done.complete(result);
    return done.future;
  }

  @override
  Future<RecordResult> get finished => done.future;

  /// 녹음이 밖의 이유(5분, 끊김)로 끝났을 때.
  void finishBySystem(RecordResult r) => done.complete(r);
}

class FakeTranscriber implements Transcriber {
  Completer<Transcript> next = Completer();
  int calls = 0;

  @override
  Future<Transcript> transcribe(String wavPath,
      {void Function(double progress)? onProgress}) {
    calls++;
    onProgress?.call(0.5);
    return next.future;
  }
}

Float32List sine(Duration d, {double hz = 180}) => Float32List.fromList(
    List.generate(16000 * d.inMilliseconds ~/ 1000,
        (i) => 0.4 * sin(2 * pi * hz * i / 16000)));

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late Database db;
  late SessionRepository sessions;
  late FakeRecorder recorder;
  late FakeTranscriber transcriber;
  late PracticeController c;
  final script = Script(
      id: 1, title: '경제', body: '경제가 크게 성장했습니다', createdAt: DateTime(2026));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('practice_test');
    db = await openAppDatabase(inMemoryDatabasePath, factory: databaseFactoryFfi);
    await db.insert('scripts', {
      'id': 1,
      'title': '경제',
      'body': script.body,
      'created_at': 0,
    });
    sessions = SessionRepository(db);
    recorder = FakeRecorder();
    transcriber = FakeTranscriber();
    c = PracticeController(
      script: script,
      recorder: recorder,
      transcriber: transcriber,
      sessions: sessions,
    );
  });

  tearDown(() async {
    c.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  RecordResult recording(Float32List samples, {bool interrupted = false}) {
    final path = p.join(dir.path, 'take_${DateTime.now().microsecondsSinceEpoch}.wav');
    writeWav(path, samples);
    return RecordResult(
      wavPath: path,
      elapsed: Duration(milliseconds: samples.length * 1000 ~/ 16000),
      interrupted: interrupted,
    );
  }

  test('시작→정지: 세션 저장, 시간·분당 음절·억양이 바로 채워지고 인식 중에도 metricsReady', () async {
    await c.start();
    expect(c.state.phase, PracticePhase.recording);
    recorder.result = recording(sine(const Duration(seconds: 2)));
    await c.stop();

    final s = c.state;
    expect(s.phase, PracticePhase.result);
    expect(s.resultStatus, ResultStatus.metricsReady);
    expect(s.session, isNotNull);
    expect(s.session!.id, isNotNull);
    expect(s.session!.elapsed.inMilliseconds, inInclusiveRange(1800, 2000));
    expect(s.session!.syllablesPerMinute, greaterThan(0));
    expect(s.intonation, isNotNull);
    expect(s.intonation!.noVoice, isFalse);
    expect(s.session!.pitch, isNotEmpty);
    expect(s.marks, isNull);
    expect(s.transcribeProgress, 0.5);
    expect(transcriber.calls, 1);

    final saved = await sessions.forScript(1);
    expect(saved, hasLength(1));
    expect(saved.single.marks, isNull);

    // 인식이 끝나면 updateMarks가 호출된다
    transcriber.next.complete(const Transcript(text: '경제가 크게 생장했습니다', words: []));
    await c.transcription;
    expect(c.state.resultStatus, ResultStatus.complete);
    expect(c.state.marks!.map((m) => m.status),
        [MarkStatus.matched, MarkStatus.matched, MarkStatus.misheard]);
    final updated = (await sessions.forScript(1)).single;
    expect(updated.marks, hasLength(3));
    expect(updated.transcript, '경제가 크게 생장했습니다');
  });

  test('무음 녹음 → "목소리가 들리지 않았어요", 기록을 남기지 않는다 (Review Focus 1)', () async {
    await c.start();
    final r = recording(Float32List(16000 * 2));
    recorder.result = r;
    await c.stop();
    expect(c.state.phase, PracticePhase.result);
    expect(c.state.message, '목소리가 들리지 않았어요');
    expect(c.state.resultStatus, ResultStatus.complete);
    expect(transcriber.calls, 0);
    expect(await sessions.forScript(1), isEmpty);
    expect(File(r.wavPath).existsSync(), isFalse);
  });

  test('마이크 권한 거부 → permissionDenied, 아무것도 저장하지 않는다', () async {
    recorder.startResult = RecordStart.permissionDenied;
    await c.start();
    expect(c.state.phase, PracticePhase.permissionDenied);
    expect(await sessions.forScript(1), isEmpty);
  });

  test('녹음 중 pcmFrames로 경과 시간과 실시간 억양 선이 채워진다', () async {
    await c.start();
    final samples = sine(const Duration(seconds: 1));
    for (var o = 0; o < samples.length; o += 1600) {
      recorder.frames.add(Float32List.sublistView(samples, o, o + 1600));
    }
    await pumpEventQueue();
    expect(c.state.elapsed, const Duration(seconds: 1));
    expect(c.state.livePitch, isNotEmpty);
    final voiced = c.state.livePitch.where((p) => p.hz != null);
    expect(voiced, isNotEmpty);
    for (final p in voiced) {
      expect(p.hz, inInclusiveRange(175, 185));
    }
    recorder.result = recording(samples);
    await c.stop();
  });

  test('전화 수신 등으로 녹음이 끊기면 그때까지로 결과를 낸다 (Review Focus 2)', () async {
    await c.start();
    recorder.finishBySystem(
        recording(sine(const Duration(seconds: 2)), interrupted: true));
    await pumpEventQueue(times: 50);
    await c.settled;
    expect(c.state.phase, PracticePhase.result);
    expect(c.state.interrupted, isTrue);
    expect(await sessions.forScript(1), hasLength(1));
  });

  test('인식이 실패해도 세션과 다른 결과는 남는다', () async {
    await c.start();
    recorder.result = recording(sine(const Duration(seconds: 2)));
    await c.stop();
    transcriber.next.completeError(Exception('model'));
    await c.transcription;
    expect(c.state.resultStatus, ResultStatus.complete);
    expect(c.state.error, isNotNull);
    expect(c.state.marks, isNull);
    expect(await sessions.forScript(1), hasLength(1));
  });

  test('녹음 중 화면을 나가면(dispose) 녹음을 멈추고 기록을 남긴다', () async {
    final other = PracticeController(
        script: script, recorder: recorder, transcriber: transcriber, sessions: sessions);
    await other.start();
    recorder.result = recording(sine(const Duration(seconds: 2)));
    other.dispose();
    await pumpEventQueue(times: 50);
    await other.settled;
    expect(recorder.done.isCompleted, isTrue);
    expect(await sessions.forScript(1), hasLength(1));
  });

  test('결과를 본 뒤 다시 연습할 수 있다', () async {
    await c.start();
    recorder.result = recording(Float32List(16000));
    await c.stop();
    c.reset();
    expect(c.state.phase, PracticePhase.idle);
    await c.start();
    expect(c.state.phase, PracticePhase.recording);
    expect(recorder.starts, 2);
  });
}
