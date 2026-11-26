# 퍼펙트딕션 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 잰말놀이·내 원고로 도전해 딕션 점수와 별을 받는 퍼펙트딕션을 만든다.
**Spec:** `docs/superpowers/specs/2026-11-27-perfect-diction-design.md`

## Global Constraints
- 점수 문구에 "발음 점수"·"발음 채점" 금지. DB는 추가만(v7). 인터넷 금지.
- 목표 속도 300/350/400, 별 70/85/95, 점수 = 정확도 0.7 + 속도 0.3, 속도 ±5% 100점 ~ ±50% 0점.

## Review Focus
1. **아무 말도 안 하고 끝남:** 점수 0, 앱이 죽지 않고 결과가 나온다. → Task 2, 5 테스트
2. **원고와 전혀 다른 말:** 정확도 0 근처. → Task 2 테스트
3. **도전 녹음이 녹음관리·연습 중에 섞이지 않음.** → Task 4 테스트
4. **잠긴 단계는 눌러도 시작하지 않는다.** → Task 5 테스트
5. **최고 점수는 낮은 점수로 덮이지 않는다.** → Task 3 테스트

### Task 1: 잰말놀이와 잠금 — `lib/data/twisters.dart`
Produces: `class Twister { String id; int stage; String title; String body; }`, `List<Twister> twisters`(15, 단계별 5), `double stagePace(int stage)`(300/350/400), `bool stageUnlocked(int stage, Map<String,int> bestStars)`(1단계 항상, n단계는 n-1단계 별 합 ≥ 5), `int starsInStage(int stage, Map<String,int> bestStars)`.

### Task 2: 점수 — `lib/analysis/diction_score.dart`
Produces: `class DictionScore { int total; double accuracy; double speed; double measuredPace; int stars; bool perfect; }`, `abstract class DictionScorer { DictionScore score({required String script, required String transcript, required Duration voiced, required double targetPace}); }`, `class OnDeviceDictionScorer`, `int starsFor(int total)`.

### Task 3: 기록 — DB v7, `lib/data/challenge_repository.dart`
Produces: `currentSchemaVersion = 7`, `ChallengeRepository`: `add(String key, DictionScore s)`, `best() → Map<String, ({int score, int stars})>`. 키: `twister:<id>`, `script:<scriptId>`.

### Task 4: 기록 없는 도전 — `PracticeController(keepRecording: false)`
녹음관리 세션을 만들지 않고, 인식이 끝나면 WAV를 지운다. 상태에 `voiced`(목소리 구간 길이)와 `transcript`.

### Task 5: 화면 — `perfect_diction_screen.dart`, `challenge_screen.dart`, 결과 뷰
도전 목록(별 합계, 단계, 잠금, 두 탭) → 도전(3-2-1, 노래방, 목표 속도 표시) → 결과(점수, 별, PERFECT, 정확도·속도, 다르게 들린 단어, 다시 도전). 메인 메뉴 "준비 중" 제거.
