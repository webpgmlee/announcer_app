import 'compare.dart';

/// 이 횟수 이상 틀린 어절을 "자주 틀림"으로 표시한다.
const frequentErrorMin = 2;

/// 한 원고의 여러 녹음에서 어절별로 몇 번 틀렸는지.
class WordErrorStats {
  const WordErrorStats({required this.recognized, required this.wrong});

  /// 인식까지 끝난 녹음 수.
  final int recognized;

  /// 어절 번호 → 다르게 들렸거나 빠진 횟수 (0번은 넣지 않음).
  final Map<int, int> wrong;

  bool isFrequent(int wordIndex) => (wrong[wordIndex] ?? 0) >= frequentErrorMin;
}

/// 녹음별 비교 결과에서 어절별 틀린 횟수를 센다.
/// 덧붙인 말(extra)을 빼면 비교 결과는 원고 어절과 순서대로 하나씩 맞는다.
WordErrorStats errorStats(Iterable<List<WordMark>?> sessionMarks) {
  var recognized = 0;
  final wrong = <int, int>{};
  for (final marks in sessionMarks) {
    if (marks == null) continue;
    recognized++;
    var i = 0;
    for (final mark in marks) {
      if (mark.status == MarkStatus.extra) continue;
      if (mark.status == MarkStatus.misheard || mark.status == MarkStatus.missing) {
        wrong[i] = (wrong[i] ?? 0) + 1;
      }
      i++;
    }
  }
  return WordErrorStats(recognized: recognized, wrong: wrong);
}
