import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:announcer_app/analysis/compare.dart';
import 'package:announcer_app/analysis/karaoke.dart';
import 'package:announcer_app/analysis/script_layout.dart';
import 'package:announcer_app/analysis/syllable_rate.dart';
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


  group('노래방식 진행', () {
    // '경제가 크게 성장했습니다': 3+2+6 = 11음절, 표시 없음
    void feed(Duration d) {
      final s = sine(d);
      for (var o = 0; o < s.length; o += 1600) {
        recorder.frames.add(Float32List.sublistView(s, o, (o + 1600).clamp(0, s.length)));
      }
    }

    KaraokeTimeline timeline(double pace) =>
        KaraokeTimeline(scriptWords(script.body), const {}, pace);

    test('기본 속도는 350, 녹음 전에는 바꿀 수 있고 범위로 맞춘다', () {
      expect(c.pace, defaultPace);
      c.setPace(123);
      expect(c.pace, 200);
      c.setPace(380);
      expect(c.pace, 380);
    });

    test('시작하면 3-2-1 카운트다운 뒤 진행이 시작된다', () async {
      await c.start();
      expect(c.state.countdown, 3);
      expect(c.state.karaoke, isFalse);
      feed(const Duration(seconds: 1));
      await pumpEventQueue();
      expect(c.state.countdown, 2);
      feed(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(c.state.countdown, isNull);
      expect(c.state.karaoke, isTrue);
      expect(c.state.word, 0);
      recorder.result = recording(sine(const Duration(seconds: 3)));
      await c.stop();
    });

    test('진행 위치는 녹음된 소리 길이로 잰 시간표를 따른다', () async {
      c.setPace(300);
      await c.start();
      feed(const Duration(milliseconds: 3800)); // 진행 0.8초
      await pumpEventQueue();
      final f = timeline(300).at(const Duration(milliseconds: 800));
      expect(c.state.word, f.word);
      expect(c.state.wordFill, closeTo(f.wordFill, 1e-9));
      expect(c.state.position, f.position);
      expect(c.state.progress, closeTo(f.progress, 1e-9));
      expect(c.state.remaining, f.remaining);
      recorder.result = recording(sine(const Duration(seconds: 4)));
      await c.stop();
    });

    test('녹음 중에는 속도를 바꿀 수 없다 (Review Focus 3)', () async {
      await c.start();
      c.setPace(450);
      expect(c.pace, defaultPace);
      recorder.result = recording(Float32List(16000));
      await c.stop();
      c.setPace(450);
      expect(c.pace, 450);
    });

    void silence(Duration d) {
      final n = 16000 * d.inMilliseconds ~/ 1000;
      for (var o = 0; o < n; o += 1600) {
        recorder.frames.add(Float32List(min(1600, n - o)));
      }
    }

    test('원고가 끝나고 말을 멈추면 1.5초 뒤 저절로 녹음을 멈추고 저장한다', () async {
      await c.start();
      recorder.result = recording(sine(const Duration(seconds: 7)));
      final progressEnd = countdownLength + timeline(defaultPace).total;
      feed(progressEnd);
      silence(endHold - const Duration(milliseconds: 300));
      await pumpEventQueue();
      expect(c.state.phase, PracticePhase.recording);
      silence(const Duration(milliseconds: 500));
      await pumpEventQueue(times: 50);
      await c.settled;
      expect(recorder.done.isCompleted, isTrue);
      expect(c.state.phase, PracticePhase.result);
      expect(await sessions.forScript(1), hasLength(1)); // 저장됨
    });

    test('진행보다 늦게 읽어 아직 말하는 중이면 끊지 않고, 말을 멈춘 뒤 멈춘다', () async {
      await c.start();
      recorder.result = recording(sine(const Duration(seconds: 9)));
      final progressEnd = countdownLength + timeline(defaultPace).total;
      feed(progressEnd + const Duration(seconds: 3)); // 진행이 끝난 뒤에도 3초 더 읽음
      await pumpEventQueue();
      expect(c.state.phase, PracticePhase.recording);
      silence(endHold + const Duration(milliseconds: 200));
      await pumpEventQueue(times: 50);
      await c.settled;
      expect(c.state.phase, PracticePhase.result);
    });

    test('소리가 계속 나도 진행이 끝나고 10초 뒤에는 반드시 멈춘다', () async {
      await c.start();
      recorder.result = recording(sine(const Duration(seconds: 16)));
      final progressEnd = countdownLength + timeline(defaultPace).total;
      feed(progressEnd + maxOvertime - const Duration(milliseconds: 300));
      await pumpEventQueue();
      expect(c.state.phase, PracticePhase.recording);
      feed(const Duration(milliseconds: 500));
      await pumpEventQueue(times: 50);
      await c.settled;
      expect(c.state.phase, PracticePhase.result);
      expect(maxOvertime, const Duration(seconds: 10));
    });

    test('카운트다운 중에 멈춰도 결과가 나온다 (Review Focus 2)', () async {
      await c.start();
      feed(const Duration(seconds: 1));
      await pumpEventQueue();
      recorder.result = recording(sine(const Duration(seconds: 1)));
      await c.stop();
      expect(c.state.phase, PracticePhase.result);
      expect(c.state.resultStatus, isNotNull);
      expect(c.state.session, isNotNull);
    });

    test('바꾼 끊어 읽기 표시도 진행 시간표에 반영된다', () async {
      c.pauses = {0: Pause.breath};
      await c.start();
      feed(countdownLength + Duration(microseconds: (3 * 60e6 / 350).round() + 300000));
      await pumpEventQueue();
      expect(c.state.word, 0); // 숨 쉬는 중
      expect(c.state.wordFill, 1);
      recorder.result = recording(sine(const Duration(seconds: 4)));
      await c.stop();
    });
  });

  group('빠르기 알림', () {
    // 자동 정지가 오지 않도록 긴 원고 (약 20초)
    final long = Script(
        id: 1,
        title: '긴 원고',
        body: List.filled(10, '경제가 크게 성장했습니다').join(' '),
        createdAt: DateTime(2026));
    late PracticeController lc;
    setUp(() => lc = PracticeController(
        script: long, recorder: recorder, transcriber: transcriber, sessions: sessions));
    tearDown(() => lc.dispose());

    /// [spm] 빠르기의 음절 같은 소리 덩어리를 0.1초씩 넣는다.
    void feedBursts(double spm, Duration d) {
      final n = 16000 * d.inMilliseconds ~/ 1000;
      final period = 16000 * 60 / spm;
      final s = Float32List.fromList(List.generate(n, (i) {
        final phase = (i % period) / period;
        final env = phase < 0.6 ? sin(pi * phase / 0.6) : 0.0;
        return 0.3 * env * sin(2 * pi * 180 * i / 16000);
      }));
      for (var o = 0; o < s.length; o += 1600) {
        recorder.frames.add(Float32List.sublistView(s, o, min(o + 1600, s.length)));
      }
    }

    Future<void> run(double spm) async {
      await lc.start();
      recorder.frames.add(Float32List(16000 * 3)); // 카운트다운 동안 조용히
      feedBursts(spm, const Duration(seconds: 4));
      await pumpEventQueue();
    }

    test('진행 속도보다 빠르게 읽으면 빨라요', () async {
      await run(480);
      expect(lc.state.paceFeedback, PaceFeedback.fast);
      recorder.result = recording(sine(const Duration(seconds: 7)));
      await lc.stop();
    });

    test('진행 속도보다 느리게 읽으면 느려요', () async {
      await run(240);
      expect(lc.state.paceFeedback, PaceFeedback.slow);
      recorder.result = recording(sine(const Duration(seconds: 7)));
      await lc.stop();
    });

    test('진행 속도와 비슷하면 아무것도 띄우지 않는다', () async {
      await run(350);
      expect(lc.state.paceFeedback, PaceFeedback.none);
      recorder.result = recording(sine(const Duration(seconds: 7)));
      await lc.stop();
    });

    test('카운트다운 중에는 소리가 커도 알리지 않는다', () async {
      await lc.start();
      feedBursts(600, const Duration(milliseconds: 2900));
      await pumpEventQueue();
      expect(lc.state.countdown, isNotNull);
      expect(lc.state.paceFeedback, PaceFeedback.none);
      recorder.result = recording(sine(const Duration(seconds: 3)));
      await lc.stop();
    });

    test('바꾼 진행 속도를 기준으로 판단한다', () async {
      lc.setPace(480);
      await run(480);
      expect(lc.state.paceFeedback, PaceFeedback.none);
      recorder.result = recording(sine(const Duration(seconds: 7)));
      await lc.stop();
    });
  });

  group('퍼펙트딕션 도전 모드 (기록을 남기지 않음)', () {
    late PracticeController cc;
    setUp(() => cc = PracticeController(
        script: Script(title: '간장', body: '경제가 크게 성장했습니다', createdAt: DateTime(2026)),
        recorder: recorder,
        transcriber: transcriber,
        sessions: sessions,
        keepRecording: false,
        pace: 300));
    tearDown(() => cc.dispose());

    test('녹음관리 기록을 만들지 않고, 인식이 끝나면 녹음 파일을 지운다 (Review Focus 3)', () async {
      await cc.start();
      final r = recording(sine(const Duration(seconds: 2)));
      recorder.result = r;
      await cc.stop();
      expect(cc.state.phase, PracticePhase.result);
      expect(cc.state.voiced, isNotNull);
      expect(cc.state.voiced!.inMilliseconds, inInclusiveRange(1800, 2000));
      transcriber.next.complete(const Transcript(text: '경제가 크게 생장했습니다', words: []));
      await cc.transcription;
      expect(cc.state.resultStatus, ResultStatus.complete);
      expect(cc.state.transcript, '경제가 크게 생장했습니다');
      expect(await sessions.all(), isEmpty);
      expect(File(r.wavPath).existsSync(), isFalse);
    });

    test('아무 말도 안 하면 바로 결과(목소리 없음)이고 기록도 없다', () async {
      await cc.start();
      recorder.result = recording(Float32List(16000));
      await cc.stop();
      expect(cc.state.message, noVoiceMessage);
      expect(cc.state.voiced, Duration.zero);
      expect(await sessions.all(), isEmpty);
    });

    test('도전은 정해진 속도를 쓴다', () => expect(cc.pace, 300));
  });
}
