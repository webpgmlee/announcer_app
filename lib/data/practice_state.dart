import 'models.dart';

/// 원고 하나의 녹음 통계.
typedef PracticeStat = ({int count, DateTime last});

/// 연습 중인 원고: 녹음한 적이 있고, 마지막 녹음이 "연습 완료"보다 나중인 원고.
/// 녹음하면 자동으로 연습 중이 되고, 연습 완료를 누르면 분야 목록으로 돌아간다.
bool isPracticing(Script s, PracticeStat? stat) {
  if (stat == null) return false;
  final done = s.completedAt;
  return done == null || stat.last.isAfter(done);
}
