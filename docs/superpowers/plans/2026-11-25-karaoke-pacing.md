# 노래방식 원고 진행 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 녹음 화면의 원고 진행을 정해진 속도(기본 350음절/분, 조절 가능)의 노래방식으로 바꾸고 v0.3.0-dev로 배포한다.

**Architecture:** 진행 시간표는 순수 함수(`KaraokeTimeline`)로 만들고, 컨트롤러는 녹음된 소리 길이를 시계로 써서 시간표를 읽는다. 실시간 인식은 지운다.

**Spec:** `docs/superpowers/specs/2026-11-25-karaoke-pacing-design.md`

## Global Constraints

- 기본 350음절/분, 범위 200~500, 단계 10. `/` 0.3초, `//` 0.6초. 카운트다운 3초. 끝난 뒤 1.5초에 자동 정지.
- DB 변경은 추가만 (v4 `settings`).
- 화면 문구 한국어, "발음 점수"·"발음 채점" 금지, 인터넷 금지.

## Review Focus

1. **빈 원고 또는 음절이 없는 원고(기호만):** 진행 시간 0 → 카운트다운 뒤 곧 자동 정지, 앱이 죽지 않는다. → Task 1, 3 테스트
2. **카운트다운 중 정지:** 결과가 정상(무음이면 안내)으로 나온다. → Task 3 테스트
3. **녹음 중 속도 변경 시도:** 무시된다. → Task 3 테스트
4. **저장된 속도가 범위 밖(예전 값·손상):** 범위로 맞춘다. → Task 2 테스트

### Task 1: 진행 시간표

**Files:** Create `lib/analysis/karaoke.dart` · Test `test/analysis/karaoke_test.dart`
**Produces:**
- 상수 `defaultPace = 350.0`, `minPace = 200.0`, `maxPace = 500.0`, `paceStep = 10.0`, `pauseGap = 0.3s`, `breathGap = 0.6s`, `countdown = 3s`, `endHold = 1.5s`
- `double clampPace(double v)` (범위·10 단위로 반올림)
- `List<ScriptLine> sentencesOf(int wordCount, Map<int, Pause> pauses)` (`//`에서만 나눔)
- `class KaraokeFrame { int word; double wordFill; int sentence; int position; double progress; Duration remaining; bool done; }`
- `class KaraokeTimeline { KaraokeTimeline(List<String> words, Map<int, Pause> pauses, double pace); Duration get total; KaraokeFrame at(Duration t); }` — t<0이면 첫 어절 0, t≥total이면 done
- [ ] 테스트: 350음절/분에서 "안녕하십니까." (6음절) = 6×60/350초 + 0.6초; 어절 중간에 wordFill 0.5; 쉼 구간에서는 앞 어절 fill 1, 다음 어절 0; 문장 번호; 빈 원고 total 0, done; 속도 두 배면 음절 시간 절반; clampPace(123)=200, clampPace(347)=350.

### Task 2: 속도 저장 (DB v4)

**Files:** Modify `lib/data/database.dart` · Create `lib/data/settings_repository.dart` · Test `test/data/settings_repository_test.dart`
**Produces:** `currentSchemaVersion = 4`, `SettingsRepository(Database)`: `Future<double> pace()` (없으면 defaultPace, 범위 밖은 clampPace), `Future<void> setPace(double)`
- [ ] 테스트: 기본 350; 저장·조회; 범위 밖 값 보정; v3 DB → v4 업그레이드 시 데이터 유지.

### Task 3: 컨트롤러

**Files:** Modify `lib/practice/practice_controller.dart`, `lib/providers.dart` · Delete `lib/speech/live_transcriber.dart` · Test `test/practice/practice_controller_test.dart`
**Consumes:** Task 1 시간표. **Produces:** `PracticeController({..., double pace = defaultPace})`, `double get pace`, `void setPace(double)`(녹음 중 무시), `PracticeState`에 `int? countdown`, `int word`, `double wordFill`, `int sentence`, `bool karaoke`(진행 중) 추가; `estimating`·`speed` 제거.
- [ ] 테스트: 시작 직후 countdown 3, 소리 1초 뒤 2, 3초 뒤 null이고 진행 시작; 3초+α에 word/position이 시간표와 같음; 끝+1.5초 넘으면 자동 정지되어 결과; 녹음 중 setPace 무시; 카운트다운 중 정지해도 결과; 실시간 인식 테스트는 지움; 기존 결과 테스트 유지.

### Task 4: 화면

**Files:** Modify `lib/widgets/prompter.dart`, `lib/screens/record_screen.dart`, `lib/widgets/studio.dart`(PaceControl) · Test `test/widgets/prompter_test.dart`, `test/screens/home_shell_test.dart`
- `Prompter`에 `activeWord`, `wordFill`, `currentSentence(ScriptLine?)`, `karaoke` 추가: 지금 문장의 줄은 크게, 채운 글자는 진하게, 안 채운 글자는 흐리게.
- `PaceControl({pace, enabled, onChanged})`: `−` `350` `+`, 단위 "음절/분".
- [ ] 테스트: 진행 중 지금 어절의 앞 글자만 진하게(RichText 두 부분); 지금 문장 줄 키 `line-i-current`; 속도 + 누르면 360으로 저장되고 앱을 다시 그려도 360; 녹음 중에는 버튼이 꺼짐; 카운트다운 숫자 표시.

### Task 5: 빌드·배포

- [ ] 버전 0.3.0+3, `flutter test`·`check_release`·`flutter build apk --release` 성공, Release `v0.3.0-dev`, 다운로드 페이지·gh-pages 갱신, 링크 확인.
