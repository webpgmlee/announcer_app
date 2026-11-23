# 아나운서 발음·스피킹 교정 앱 v1 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 원고를 읽으면 녹음, 시간, 말 빠르기, 억양 선, 원고 비교 결과를 보여주는 Flutter 앱 v1(무료, 서버 없음)을 만든다.

**Architecture:** 화면(UI)과 분석 로직을 분리한다. 음절 세기, 숫자 읽기, 원고 비교, 음높이 분석은 순수 Dart 함수로 만들어 `flutter test`로 검증한다. 녹음, 재생, 음성 인식처럼 기기에 의존하는 부분은 인터페이스 뒤에 두고, 화면은 인터페이스만 안다. 음성 인식은 앱에 내장한 Whisper 계열 모델(whisper.cpp)로 iOS·안드로이드 모두 같은 엔진을 쓴다.

**Tech Stack:** Flutter 3.50(stable), Dart. `record`(녹음·PCM 스트림), `just_audio`(재생), `sqflite` + `path_provider`(로컬 저장), `fl_chart`(억양 선), `flutter_riverpod`(상태 관리), whisper.cpp 바인딩 패키지(Task 1에서 확정).

**Spec:** `docs/specs/2026-11-23-announcer-app-design.md`

## Global Constraints

- 지원: 안드로이드와 iOS. 안드로이드 13 미만 기기에서도 원고 비교를 포함한 모든 기능이 동작해야 한다.
- 서버 없음, 로그인 없음, 결제 없음, 분석 SDK(Firebase 등) 없음. 어떤 데이터도 폰 밖으로 보내지 않는다.
- 녹음 1회 최대 5분. 5분이 되면 자동으로 멈춘다.
- 앱 안 문구에 "발음 채점", "발음 점수"라는 말을 쓰지 않는다. v1 비교 기능의 이름은 "다르게 들린 단어 표시"다.
- B 기능(Azure) 코드는 이 계획에 없다. 출시 빌드에 들어가면 안 된다.
- 원고 데이터 구조에 `category`, `difficulty`, `isPremium` 칸을 둔다(v1에서는 사용자 원고만 있고 모두 무료).
- 음절 세기: 한글 1글자 = 1음절, 숫자·영어 약어·기호는 읽는 소리로 바꿔 센다, 문장부호·공백은 세지 않는다.

## Review Focus

1. **빈 녹음·무음:** 아무 말도 안 하고 멈추면 앱이 죽지 않고 "목소리가 들리지 않았어요"를 보여준다. → Task 6, 8 테스트
2. **녹음 중 전화 수신·앱 백그라운드 전환:** 녹음이 끊기면 그때까지 녹음된 것을 저장하고 결과를 낸다. → Task 4 테스트
3. **마이크 권한 거부:** 녹음 버튼이 설정으로 가는 안내를 띄우고 앱이 멈추지 않는다. → Task 4 테스트
4. **숫자·영어만 있는 원고, 빈 원고:** 빈 원고는 저장할 수 없고, 숫자만 있는 원고도 음절 수가 0보다 크게 나온다. → Task 2, 3 테스트
5. **앱 업데이트 후 기록 유지:** DB 스키마 버전이 올라가도 기존 녹음과 기록이 남는다. → Task 3 테스트

---

### Task 1: 프로젝트 생성과 음성 인식 엔진 확인 (시험용)

가장 불확실한 부분부터 확인한다. 여기서 정한 패키지와 모델이 Task 7의 전제다.

**Files:**
- Create: Flutter 프로젝트 `announcer_app` (`flutter create --org kr.tg --platforms android,ios announcer_app`)
- Create: `spike/whisper_spike.dart` (확인 후 삭제)
- Create: `docs/decisions/speech-engine.md`

- [ ] **Step 1:** pub.dev에서 whisper.cpp 바인딩 후보를 2~3개 고른다. 기준은 안드로이드·iOS 지원, 최근 업데이트, 파일 입력 지원이다.
- [ ] **Step 2:** 실제 안드로이드 폰에서 1분 분량 한국어 뉴스 낭독 WAV(16kHz 모노)를 `base`와 `small` 양자화 모델로 각각 인식한다. 걸린 시간, 앱 크기 증가, 인식 결과를 기록한다.
- [ ] **Step 3:** 다음 기준으로 정하고 `docs/decisions/speech-engine.md`에 적는다. 1분 녹음 인식이 중급 폰에서 60초 이내이고, 원고 대비 단어 일치율이 90% 이상이어야 한다. 기준을 못 넘으면 사용자에게 보고하고 멈춘다.
- [ ] **Step 4:** 모델 전달 방식(앱에 포함 / Play Asset Delivery / On-Demand Resources)을 정해 같은 문서에 적는다.
- [ ] **Step 5:** 시험 코드를 지우고 `pubspec.yaml`에 확정한 패키지를 추가해 커밋한다.

```bash
git commit -m "chore: create project and pick on-device speech engine"
```

### Task 2: 숫자·영어 읽기 변환과 음절 세기

**Files:**
- Create: `lib/analysis/read_aloud.dart`, `lib/analysis/syllables.dart`
- Test: `test/analysis/syllables_test.dart`

**Interfaces:**
- Produces: `String readAloud(String text)` (숫자, 영어 약어, 기호를 한글 읽는 소리로 바꾼다), `int countSyllables(String script)`, `double syllablesPerMinute(int syllables, Duration elapsed)`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
test('한글은 글자당 1음절, 공백·문장부호 제외', () {
  expect(countSyllables('안녕하세요. 뉴스입니다!'), 9);
});
test('숫자는 읽는 소리로', () {
  expect(readAloud('2026년'), '이천이십육년');
  expect(countSyllables('2026년'), 6);
  expect(countSyllables('3.5%'), 6); // 삼점오퍼센트
});
test('영어 약어는 알파벳 이름으로', () {
  expect(readAloud('KBS'), '케이비에스');
  expect(countSyllables('KBS'), 5);
});
test('빈 문자열은 0', () => expect(countSyllables(''), 0));
test('분당 음절', () {
  expect(syllablesPerMinute(300, const Duration(seconds: 60)), 300);
  expect(syllablesPerMinute(150, const Duration(seconds: 30)), 300);
  expect(syllablesPerMinute(100, Duration.zero), 0);
});
```

- [ ] **Step 2:** `flutter test test/analysis/syllables_test.dart` → FAIL(함수 없음)
- [ ] **Step 3:** 구현한다. 숫자는 한자어 수사(일, 십, 백, 천, 만, 억, 조)로 읽고 소수점은 "점"으로 읽는다. 영어 대문자 약어는 알파벳 이름표(A=에이 … Z=지)로 읽는다. 기호는 %→퍼센트, ℃→도, ~→에서로 바꾼다. 고유어 수사(세 명, 다섯 시)는 v1 범위 밖이다.
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** 커밋 `feat: syllable counting with read-aloud conversion`

### Task 3: 원고·연습 기록 저장소

**Files:**
- Create: `lib/data/models.dart`, `lib/data/database.dart`, `lib/data/script_repository.dart`, `lib/data/session_repository.dart`
- Test: `test/data/repository_test.dart` (`sqflite_common_ffi`로 메모리 DB 사용)

**Interfaces:**
- Produces:
  - `class Script { int? id; String title; String body; String? category; int? difficulty; bool isPremium; DateTime createdAt; }`
  - `class PracticeSession { int? id; int scriptId; String audioPath; Duration elapsed; double syllablesPerMinute; List<PitchPoint> pitch; List<WordMark>? marks; DateTime createdAt; }` (`PitchPoint`는 Task 6, `WordMark`는 Task 8)
  - `ScriptRepository`: `Future<int> add(Script)`, `Future<List<Script>> all()`, `Future<void> delete(int id)`
  - `SessionRepository`: `Future<int> add(PracticeSession)`, `Future<void> updateMarks(int id, List<WordMark>)`, `Future<List<PracticeSession>> forScript(int scriptId)`, `Future<void> delete(int id)` (오디오 파일도 지운다)

- [ ] **Step 1: 실패하는 테스트 작성**: 원고 추가 후 조회, 본문이 공백뿐인 원고는 `ArgumentError`, 세션 저장 후 `forScript`로 조회, 세션 삭제 시 오디오 파일도 삭제, **스키마 v1 DB에 데이터를 넣고 v2로 열어도 데이터 유지**(Review Focus 5).
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현한다. `pitch`와 `marks`는 JSON 문자열 열로 저장한다. 오디오 파일은 앱 문서 폴더 `recordings/` 아래에 둔다. `onUpgrade`에서 열 추가만 하고 테이블을 지우지 않는다.
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** 커밋 `feat: local storage for scripts and practice sessions`

### Task 4: 녹음과 재생

**Files:**
- Create: `lib/audio/recorder.dart`, `lib/audio/player.dart`
- Test: `test/audio/recorder_test.dart` (가짜 `record` 구현으로)

**Interfaces:**
- Produces:
  - `abstract class Recorder { Future<RecordStart> start(); Stream<Float32List> get pcmFrames; Future<RecordResult> stop(); }`
  - `enum RecordStart { ok, permissionDenied }`
  - `class RecordResult { String wavPath; Duration elapsed; bool interrupted; }`
  - 녹음 형식: 16kHz, 모노, PCM16 WAV (Whisper 입력과 같다)
  - `abstract class Player { Future<void> play(String path); Future<void> pause(); Stream<Duration> get position; }`

- [ ] **Step 1: 실패하는 테스트 작성**: 5분이 지나면 자동 정지(`elapsed == 5분`), 권한 거부 시 `RecordStart.permissionDenied`, 오디오 세션이 끊기면(전화 수신·백그라운드) `interrupted: true`이고 그때까지의 WAV가 남는다(Review Focus 2, 3).
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** `record` 패키지의 스트림 녹음으로 PCM을 받아 WAV로 쓰면서 `pcmFrames`로도 흘려보낸다(실시간 억양 선용). 재생은 `just_audio`로 구현한다.
- [ ] **Step 4:** 테스트 → PASS. 실제 폰에서 녹음 → 재생을 한 번 확인한다.
- [ ] **Step 5:** 커밋 `feat: 16kHz recording with live PCM stream and playback`

### Task 5: 원고 목록과 첫 화면

**Files:**
- Create: `lib/app.dart`, `lib/main.dart`, `lib/screens/script_list_screen.dart`, `lib/screens/script_edit_screen.dart`
- Test: `test/screens/script_list_test.dart`

**Interfaces:**
- Consumes: `ScriptRepository` (Task 3)

- [ ] **Step 1: 실패하는 위젯 테스트 작성**: 원고가 0개면 "연습할 원고를 붙여넣어 주세요" 안내와 붙여넣기 버튼이 보인다. 붙여넣고 저장하면 목록에 제목과 음절 수가 나온다. 빈 본문은 저장 버튼이 꺼져 있다.
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현한다. 제목을 비우면 본문 앞 20자를 제목으로 쓴다.
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** 커밋 `feat: script list with paste-first onboarding`

### Task 6: 음높이 분석과 억양 판단

Metrona 기술 가이드(03번 파일)를 받았으면 그 알고리즘을 옮기고, 아래 인터페이스와 테스트는 그대로 둔다.

**Files:**
- Create: `lib/analysis/pitch.dart`, `lib/analysis/intonation.dart`
- Test: `test/analysis/pitch_test.dart`, `test/analysis/intonation_test.dart`

**Interfaces:**
- Produces:
  - `class PitchPoint { Duration t; double? hz; }` (무성 구간은 `hz == null`)
  - `List<PitchPoint> analyzePitch(Float32List samples, {int sampleRate = 16000, Duration hop = const Duration(milliseconds: 10)})`
  - `class IntonationReport { List<DurationRange> flatRanges; List<Duration> risingEnds; bool noVoice; }`
  - `IntonationReport analyzeIntonation(List<PitchPoint> pitch)`

- [ ] **Step 1: 실패하는 테스트 작성**
  - 200Hz 사인파 1초 → 유성 프레임의 hz가 모두 196~204 범위
  - 무음 1초 → 모든 hz가 null이고 `analyzeIntonation(...).noVoice == true` (Review Focus 1)
  - 3초 동안 hz 변화폭 1반음 미만 → `flatRanges`에 그 구간이 들어감
  - 문장 끝(무성 0.3초 직전 0.4초) 동안 3반음 이상 상승 → `risingEnds`에 그 시점이 들어감
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** YIN으로 구현한다(창 40ms, 임계값 0.15, 범위 70~500Hz). 기준값(1반음, 3초, 3반음)은 `intonation.dart` 맨 위 상수로 둔다.
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** 커밋 `feat: YIN pitch tracking and intonation report`

### Task 7: 음성 인식 연결

**Files:**
- Create: `lib/speech/transcriber.dart`, `lib/speech/whisper_transcriber.dart`
- Test: `test/speech/transcriber_test.dart` (가짜 엔진으로 나누기·이어붙이기만 검증)

**Interfaces:**
- Produces:
  - `class Transcript { String text; List<TimedWord> words; }`, `class TimedWord { String word; Duration start; Duration end; }`
  - `abstract class Transcriber { Future<Transcript> transcribe(String wavPath, {void Function(double progress)? onProgress}); }`
  - `class WhisperTranscriber implements Transcriber` (언어 `ko` 고정, Task 1에서 정한 모델)

- [ ] **Step 1: 실패하는 테스트 작성**: 75초 WAV를 30초 단위 3조각으로 나누고, 단어 시간은 조각 시작 시간만큼 밀어서 이어 붙인다. `onProgress`는 0→1로 증가한다. 무음 WAV는 빈 `Transcript`를 돌려준다.
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현한다. 인식은 별도 isolate에서 돌려 화면이 멈추지 않게 한다.
- [ ] **Step 4:** 테스트 → PASS. 실제 폰에서 1분 녹음을 인식해 본다.
- [ ] **Step 5:** 커밋 `feat: on-device whisper transcription with chunking`

### Task 8: 원고 비교

**Files:**
- Create: `lib/analysis/compare.dart`
- Test: `test/analysis/compare_test.dart`

**Interfaces:**
- Consumes: `readAloud` (Task 2)
- Produces:
  - `enum MarkStatus { matched, misheard, missing, extra }`
  - `class WordMark { String scriptWord; String? heardWord; MarkStatus status; double? score; }` (`score`는 나중에 B가 채운다. v1은 항상 null)
  - `List<WordMark> compareToScript(String script, String transcript)`

- [ ] **Step 1: 실패하는 테스트 작성**
  - 같은 문장 → 모두 `matched`
  - 원고 "경제가 성장했습니다", 인식 "경제가 생장했습니다" → 두 번째가 `misheard`, `heardWord == '생장했습니다'`
  - 단어 하나 빠짐 → `missing`, 단어 하나 더함 → `extra`
  - 띄어쓰기만 다름("성장 했습니다" vs "성장했습니다") → 모두 `matched`
  - 원고 "2026년", 인식 "이천이십육년" → `matched`
  - 인식이 빈 문자열 → 모두 `missing` (Review Focus 1)
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 양쪽을 `readAloud`로 바꾸고 문장부호를 지운 뒤, 음절 단위 편집 거리로 정렬하고 결과를 원고 어절 단위로 묶는다.
- [ ] **Step 4:** 테스트 → PASS
- [ ] **Step 5:** 커밋 `feat: script-vs-transcript comparison`

### Task 9: 연습 화면과 결과 화면

**Files:**
- Create: `lib/screens/practice_screen.dart`, `lib/screens/result_screen.dart`, `lib/widgets/pitch_line.dart`, `lib/widgets/marked_script.dart`, `lib/practice/practice_controller.dart`
- Test: `test/practice/practice_controller_test.dart`, `test/widgets/marked_script_test.dart`

**Interfaces:**
- Consumes: Task 2~8의 모든 Produces

- [ ] **Step 1: 실패하는 테스트 작성**
  - 컨트롤러: 시작→정지하면 세션이 저장되고, 시간·분당 음절·억양이 바로 채워지고, 인식이 끝나면 `updateMarks`가 호출된다. 인식 중에도 결과 화면 상태가 `metricsReady`다.
  - 무음 녹음 → 결과 상태에 "목소리가 들리지 않았어요" 메시지(Review Focus 1)
  - `MarkedScript`: `misheard`, `missing`, `extra`가 서로 다른 색, `misheard`를 누르면 "이렇게 들렸어요: …"가 보임
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 구현한다. 연습 화면은 원고(큰 글씨), 경과 시간, 실시간 억양 선(`pcmFrames` → `analyzePitch`)을 보여준다. 결과 화면은 재생 버튼, 시간, 분당 음절, 억양 선(단조 구간·끝 올림 표시), 원고 비교를 보여준다. 비교 영역 제목은 "다르게 들린 단어"다.
- [ ] **Step 4:** 테스트 → PASS. 실제 폰에서 처음부터 끝까지 한 번 연습해 본다.
- [ ] **Step 5:** 커밋 `feat: practice and result screens`

### Task 10: 연습 기록 화면과 출시 점검

**Files:**
- Create: `lib/screens/history_screen.dart`, `tool/check_release.dart`
- Modify: `android/app/build.gradle`, `ios/Runner/Info.plist` (마이크 권한 문구)
- Test: `test/screens/history_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**: 원고별 기록이 최신순으로 나오고, 날짜·시간·분당 음절이 보이며, 밀어서 삭제하면 사라진다.
- [ ] **Step 2:** 테스트 → FAIL
- [ ] **Step 3:** 기록 화면을 구현한다. `tool/check_release.dart`는 `lib/` 전체에서 금지 문구("발음 점수", "발음 채점")와 금지 패키지(firebase, azure, http)를 찾으면 실패한다. 마이크 권한 문구는 "연습을 녹음하려면 마이크가 필요해요. 녹음은 폰 밖으로 나가지 않아요."로 한다.
- [ ] **Step 4:** `flutter test`, `dart run tool/check_release.dart`, `flutter build apk --release` → 모두 성공
- [ ] **Step 5:** 커밋 `feat: history screen and release checks`
