import 'package:sqflite/sqflite.dart';

import '../analysis/diction_score.dart';

/// 도전 키: 잰말놀이는 `twister:<아이디>`, 내 원고는 `script:<원고 번호>`.
String twisterKey(String id) => 'twister:$id';
String scriptKey(int scriptId) => 'script:$scriptId';

typedef ChallengeBest = ({int score, int stars});

/// 퍼펙트딕션 도전 기록. 점수만 남기고 녹음은 남기지 않는다.
class ChallengeRepository {
  ChallengeRepository(this._db);
  final Database _db;

  Future<void> add(String key, DictionScore s, {DateTime? at}) => _db.insert('challenge_results', {
        'challenge_key': key,
        'score': s.total,
        'accuracy': s.accuracy,
        'speed': s.speed,
        'stars': s.stars,
        'created_at': (at ?? DateTime.now()).millisecondsSinceEpoch,
      });

  /// 도전마다 최고 점수와 그때의 별.
  Future<Map<String, ChallengeBest>> best() async {
    final rows = await _db.rawQuery(
        'SELECT challenge_key, MAX(score) AS score, MAX(stars) AS stars '
        'FROM challenge_results GROUP BY challenge_key');
    return {
      for (final r in rows)
        r['challenge_key'] as String: (score: r['score'] as int, stars: r['stars'] as int),
    };
  }
}
