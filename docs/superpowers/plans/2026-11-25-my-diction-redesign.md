# My Diction 화면 개편·메모 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 시안대로 세 탭(대본/녹음/기록) 화면을 다시 그리고, 실시간 위치 따라가기·끊어 읽기 표시·어절 메모·자주 틀림 표시를 넣은 My Diction v0.2.0-dev APK를 GitHub에 배포한다.

**Architecture:** 기존 구조(녹음 `Recorder`, 저장 repository, 비교 `compareToScript`, 억양 `analyzePitch`)는 그대로 둔다. 새 로직(줄 나누기, 위치 찾기, 속도·크기, 자주 틀림)은 순수 Dart 함수로 `lib/analysis/`에 두고 테스트한다. 실시간 인식은 `LiveTranscriber` 인터페이스 뒤에 두고 `PracticeController`가 쓴다. 화면은 새 테마와 위젯으로 다시 그린다.

**Tech Stack:** Flutter 3.50, Dart 3.14, flutter_riverpod, sqflite, whisper_ggml 2.10(`startWhisperLiveSession`), fl_chart.

**Spec:** `docs/superpowers/specs/2026-11-25-my-diction-redesign-design.md` (바탕: `docs/specs/2026-11-23-announcer-app-design.md`)

## Global Constraints

- 앱 이름: `My Diction` (안드로이드 label, iOS CFBundleDisplayName, MaterialApp title).
- 녹음 화면 제목 "온에어.", 탭 이름 "대본" / "녹음" / "기록".
- 자동 표시: 쉼표(`,`) 뒤 `/`(pause), `.` `?` `!` 뒤 `//`(breath). 누르면 없음 → `/` → `//` → 없음.
- 메모 종류: 발음 / 속도 / 억양 / 강조, 어절 하나에 메모 하나, 빈 글로 저장하면 삭제.
- 자주 틀림: 인식이 끝난 녹음 중 misheard 또는 missing 횟수 ≥ 2.
- 속도: 1분당 음절 < 280 느림, > 380 빠름 (최근 10초). 크기: < -30dBFS 작게, > -10dBFS 크게 (최근 0.5초). 속도를 모를 때 350음절/분.
- 실시간 인식 늦음: 목소리가 들어오는데 6초 넘게 들린 글이 늘지 않으면 그 녹음은 추정으로 전환.
- DB 스키마 v3: 추가만 (`scripts.pause_json`, `memos` 테이블).
- 인터넷 사용 금지(글꼴 다운로드 포함). "발음 점수", "발음 채점" 문구 금지.

## Review Focus

1. **실시간 인식이 아예 시작되지 않음(모델 오류):** 녹음은 정상 진행되고 위치는 추정으로, 끝나면 파일 인식으로 비교한다. → Task 6 테스트
2. **인식 글이 원고와 전혀 다름(다른 원고를 읽음):** 위치가 엉뚱하게 튀지 않는다(뒤로 가지 않고, 큰 점프는 두 번 확인). → Task 3 테스트
3. **문장부호가 없는 원고:** 표시 없이 한 줄로 두지 않고 화면 폭에서 줄바꿈되며, 진행이 정상. → Task 1, 7 테스트
4. **v2 DB에서 업그레이드:** 원고·기록 유지, pause_json이 NULL이면 처음 열 때 자동 표시 생성. → Task 5 테스트
5. **메모가 있는 원고 삭제:** 메모도 함께 지워지고 다른 원고 메모는 남는다. → Task 5 테스트

---

### Task 1: 어절·끊어 읽기 표시·줄 나누기

**Files:** Create `lib/analysis/script_layout.dart` · Test `test/analysis/script_layout_test.dart`

**Interfaces — Produces:**
- `List<String> scriptWords(String body)` (공백으로 나눔, `compare.dart`의 어절 나누기와 같아야 함)
- `enum Pause { none, pause, breath }`, `Pause cyclePause(Pause p)`
- `Map<int, Pause> autoPauses(List<String> words)` (값이 none인 항목은 넣지 않음)
- `class ScriptLine { final int start; final int end; final Pause endPause; }` (`end`는 포함하지 않음)
- `List<ScriptLine> layoutLines(int wordCount, Map<int, Pause> pauses)` (표시 뒤에서 줄을 나눔)
- `List<int> syllableOffsets(List<String> words)` (어절 i 시작 전까지의 읽는 소리 글자 수, 길이 n+1)

- [ ] Step 1: 테스트 — `autoPauses(['안녕하십니까.', '11월', '23일,', '9시'])` == `{0: breath, 2: pause}`; `cyclePause` 순환; `layoutLines(4, {0: breath, 2: pause})` → `[(0,1,breath), (1,3,pause), (3,4,none)]`; 표시가 없으면 한 줄; `syllableOffsets(['KBS', '뉴스'])` == `[0, 5, 7]`.
- [ ] Step 2: 실행 → FAIL. Step 3: 구현. Step 4: PASS. Step 5: 커밋 `feat: script words, pause marks and line layout`

### Task 2: 자주 틀림 통계

**Files:** Create `lib/analysis/error_stats.dart` · Test `test/analysis/error_stats_test.dart`

**Interfaces — Consumes:** `WordMark`, `MarkStatus` (compare.dart). **Produces:**
- `const frequentErrorMin = 2;`
- `class WordErrorStats { final int recognized; final Map<int, int> wrong; bool isFrequent(int i); }`
- `WordErrorStats errorStats(Iterable<List<WordMark>?> sessionMarks)` (null 세션은 세지 않음, extra는 건너뛰고 나머지를 어절 번호 순서로 맞춤)

- [ ] Step 1: 테스트 — 세 세션 중 두 번 어절 1이 misheard/missing → `wrong[1] == 2`, `isFrequent(1)`; extra가 끼어 있어도 번호가 밀리지 않음; null 세션은 recognized에서 제외; 한 번만 틀린 어절은 frequent 아님.
- [ ] Step 2~5: FAIL → 구현 → PASS → 커밋 `feat: per-word error stats across sessions`

### Task 3: 원고 위치 찾기

**Files:** Create `lib/analysis/script_tracker.dart` · Test `test/analysis/script_tracker_test.dart`

**Interfaces — Consumes:** `readAloud`. **Produces:**
- `int alignHeardEnd(List<String> scriptUnits, List<String> heardUnits)` — 들린 글 전체를 원고 앞부분에 맞추는(원고 뒤쪽은 비용 없이 남기는) 글자 단위 편집 거리 정렬, 들린 글 끝이 닿은 원고 단위 위치를 반환.
- `List<String> readUnits(String text)` — readAloud 후 `[\p{L}\p{N}]` 글자 목록 (compare.dart와 같은 규칙).
- `class ScriptTracker { ScriptTracker(String body); int get total; int get position; double get progress; void onHeard(String fullText); void onEstimate(int units); }` — 위치는 줄지 않음; 30단위 넘는 앞으로 점프는 연속 두 번 같은 근처(±5) 결과일 때만 반영; `onEstimate`는 추정 위치(최대 total).

- [ ] Step 1: 테스트 — 원고 "시청자 여러분 안녕하십니까 11월 23일 9시 뉴스를 시작하겠습니다", 들린 "시청자 여러분 안녕하십니까" → position이 "안녕하십니까" 끝(=12 단위) 근처(±1); 들린 글이 이어지면 증가; 더 짧은 글이 와도 감소 안 함; 원고와 무관한 글 "오늘 날씨는 맑겠습니다"가 한 번 오면 30 넘게 튀지 않음(Review Focus 2); 숫자 표기 "이천이십육" vs "2026" 맞춤; progress = position/total; 빈 원고 total 0이면 progress 0.
- [ ] Step 2~5: FAIL → 구현 → PASS → 커밋 `feat: live script position tracking`

### Task 4: 속도·크기 측정

**Files:** Create `lib/analysis/live_metrics.dart` · Modify `lib/audio/wav.dart` (`Uint8List toPcm16(Float32List)`) · Test `test/analysis/live_metrics_test.dart`

**Interfaces — Produces:**
- `enum SpeedLevel { slow, ok, fast }`, `SpeedLevel speedLevel(double spm)` (280/380)
- `enum LoudLevel { quiet, ok, loud }`, `double dbfs(Float32List s)` (빈 입력 -120), `LoudLevel loudLevel(double db)` (-30/-10)
- `class SpeedMeter { void add(Duration t, int position); double? get spm; }` — 최근 10초 창, 창이 3초 미만이면 null
- `const defaultSpm = 350.0;`, `Duration remainingTime(int remainingUnits, double? spm)`
- `Uint8List toPcm16(Float32List)` (little-endian, clamp)

- [ ] Step 1: 테스트 — 경계값(279→slow, 280→ok, 381→fast), 진폭 1.0 사인 ≈ -3dBFS → loud, 0.01 → quiet, 무음 → -120; SpeedMeter 10초에 50단위 → 300; 15초 지나면 오래된 값 제외; remainingTime(350, null) == 1분; toPcm16([0, 1, -1]) 바이트.
- [ ] Step 2~5: FAIL → 구현 → PASS → 커밋 `feat: live speed and loudness metrics`

### Task 5: DB v3 — 끊어 읽기 표시와 메모

**Files:** Modify `lib/data/database.dart`, `lib/data/models.dart`, `lib/data/script_repository.dart` · Create `lib/data/memo_repository.dart` · Test `test/data/memo_repository_test.dart`, 기존 `test/data/repository_test.dart` 보완

**Interfaces — Consumes:** `Pause`, `autoPauses`, `scriptWords` (Task 1). **Produces:**
- `currentSchemaVersion = 3`
- `enum MemoKind { pronunciation, speed, intonation, emphasis }` + `String get label` (발음/속도/억양/강조)
- `class Memo { int? id; int scriptId; int wordIndex; MemoKind kind; String text; DateTime createdAt; }`
- `ScriptRepository.pauses(Script s) → Future<Map<int, Pause>>` (NULL이면 autoPauses 저장 후 반환), `setPauses(int scriptId, Map<int, Pause>)`; `delete`가 메모도 지움
- `MemoRepository(Database)`: `forScript(int scriptId) → Future<Map<int, Memo>>`, `save(Memo m) → Future<void>` (같은 어절이면 교체, 글이 공백뿐이면 삭제), `deleteForScript(int scriptId)`

- [ ] Step 1: 테스트 — pauses 자동 생성 후 저장되어 두 번째 호출도 같음; setPauses 왕복; 메모 저장·교체·빈 글 삭제; 원고 삭제 시 그 원고 메모만 삭제(Review Focus 5); v2 DB(원고·세션 있음)를 v3로 열면 데이터 유지, pause_json NULL → 자동 생성(Review Focus 4).
- [ ] Step 2~5: FAIL → 구현 → PASS → 커밋 `feat: schema v3 with pause marks and memos`

### Task 6: 실시간 인식과 연습 컨트롤러

**Files:** Create `lib/speech/live_transcriber.dart` · Modify `lib/practice/practice_controller.dart`, `lib/providers.dart` · Test `test/practice/practice_controller_test.dart` 보완

**Interfaces — Consumes:** Task 3 `ScriptTracker`, Task 4 메트릭, `ensureModelFile`. **Produces:**
- `abstract class LiveSession { void feed(Uint8List pcm16); Stream<String> get partials; Future<String> stop(); }`
- `abstract class LiveTranscriber { Future<LiveSession> start(); }`, `class WhisperLiveTranscriber implements LiveTranscriber` (`startWhisperLiveSession`, lang `ko`, `suppressNonSpeechTokens: true`, `keepModelLoaded: true`)
- `PracticeController`에 `LiveTranscriber? live` 인자 추가. `PracticeState`에 `double progress`, `int position`, `SpeedLevel? speed`, `LoudLevel loudness`, `List<double> waveform`(최근 40개 dBFS), `bool estimating`, `Duration remaining` 추가.
- `const liveLagLimit = Duration(seconds: 6);`

- [ ] Step 1: 테스트(가짜 LiveTranscriber) — partials가 오면 progress 증가; 목소리 프레임이 6초 넘게 들어오는데 partials가 늘지 않으면 `estimating == true`이고 위치가 추정으로 증가; 정상 종료 시 최종 글로 비교하고 파일 Transcriber를 부르지 않음; 늦어졌던 녹음은 파일 Transcriber 사용; `start()`가 예외를 던지면 녹음은 계속되고 estimating(Review Focus 1); 녹음 종료 시 세션 stop이 한 번 불림; 기존 테스트 유지.
- [ ] Step 2~5: FAIL → 구현 → PASS → 커밋 `feat: live recognition drives script position`

### Task 7: 새 디자인 화면

**Files:** Create `lib/theme.dart`, `lib/screens/home_shell.dart`, `lib/screens/record_screen.dart`, `lib/widgets/prompter.dart`, `lib/widgets/memo_sheet.dart`, `lib/widgets/level_chips.dart`, `lib/widgets/waveform.dart`, `lib/widgets/tape_controls.dart` · Modify `lib/app.dart`, `lib/providers.dart`(지금 원고 `currentScriptProvider`), `lib/screens/script_list_screen.dart`, `lib/screens/history_screen.dart`, `lib/screens/result_screen.dart`, `lib/widgets/marked_script.dart` · Remove `lib/screens/practice_screen.dart` · Test `test/widgets/prompter_test.dart`, `test/screens/home_shell_test.dart`, 기존 화면 테스트 갱신

**Interfaces — Consumes:** Task 1·2·5·6 전부.
- `Prompter({words, pauses, memos, stats, currentLine, onTapGap(int wordIndex), onLongPressWord(int wordIndex), editable})`
- `showMemoSheet(context, {word, wordIndex, Memo? memo, WordErrorStats stats}) → Future<Memo?>`

- [ ] Step 1: 테스트 — Prompter가 `/`, `//` 표시를 그림; 어절 사이 누르면 `onTapGap(i)`; 길게 누르면 `onLongPressWord`; 메모 글이 말풍선으로 보임; 자주 틀림 어절 옆 횟수 표시; 메모 창에서 종류 고르고 저장 시 Memo 반환, "녹음 3번 중 3번 틀림" 표시; 홈 셸에 탭 세 개, 원고 없을 때 녹음 탭 안내 "대본 탭에서 원고를 골라 주세요"; 대본 탭에서 원고 누르면 녹음 탭으로 이동하고 제목 표시; 문장부호 없는 원고도 한 줄로 넘치지 않음(Review Focus 3); 화면 어디에도 "점수"·"채점" 없음.
- [ ] Step 2: FAIL. Step 3: 구현 (시안의 색: 바탕 #F5F3EE, 빨강 #E5483B, 파랑 강조 #C8D5FF·진행 #2F6BF0, 분홍 메모 #FDE3E1; 글꼴은 시스템 고딕 w300).
- [ ] Step 4: `flutter test` 전체 PASS, `dart analyze` 문제 없음. Step 5: 커밋 `feat: My Diction redesign with prompter, memos and tabs`

### Task 8: 이름 변경·빌드·배포

**Files:** Modify `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `pubspec.yaml`(version `0.2.0+2`), `web_download/index.html`

- [ ] Step 1: 앱 이름 My Diction으로 변경, 버전 0.2.0+2.
- [ ] Step 2: `flutter test`, `dart run tool/check_release.dart`, `flutter build apk --release` → 모두 성공.
- [ ] Step 3: 커밋·푸시, GitHub pre-release `v0.2.0-dev`에 `my-diction-v0.2.0-dev.apk` 업로드, 다운로드 URL 200 확인.
- [ ] Step 4: 다운로드 페이지를 My Diction v0.2.0-dev로 바꾸고 gh-pages 갱신, 실제 페이지에서 링크 확인.
