import 'read_aloud.dart';

/// 원고의 음절 수. 숫자·영어·기호는 읽는 소리로 바꿔 세고,
/// 문장부호와 공백은 세지 않는다. 한글 완성형 글자 하나가 한 음절이다.
int countSyllables(String script) =>
    RegExp(r'[가-힣]').allMatches(readAloud(script)).length;

/// 1분당 음절 수. 걸린 시간이 0이면 0을 돌려준다.
double syllablesPerMinute(int syllables, Duration elapsed) {
  if (elapsed <= Duration.zero) return 0;
  return syllables * 60 * Duration.microsecondsPerSecond / elapsed.inMicroseconds;
}
