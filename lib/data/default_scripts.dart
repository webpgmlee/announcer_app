import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'script_repository.dart';

/// 처음 설치했을 때 넣어 두는 기본 연습 원고 (사용자가 준 연습용 뉴스 대본).
final defaultScripts = [
  Script(
    title: '기상이변으로 인한 폭우 피해',
    category: '뉴스',
    difficulty: 1,
    createdAt: DateTime(2026, 11, 25),
    body: '올해 여름, 전국적으로 기록적인 폭우가 쏟아지면서 피해가 속출하고 있습니다.\n'
        '특히 중부 지방에서는 시간당 100mm 이상의 강한 비가 내려 도로가 침수되고 '
        '차량이 고립되는 사고가 발생했습니다.\n'
        '기상청은 이번 폭우가 기후 변화로 인한 이상 기온 때문이라고 분석했습니다.\n'
        '정부는 신속한 복구 지원을 약속하며, 피해 지역 주민들에게 긴급 구호 물품을 제공하고 있습니다.\n'
        '전문가들은 앞으로 이러한 기상이변이 더 자주 발생할 가능성이 크다고 경고합니다.\n'
        '시민들은 기상 예보를 주의 깊게 확인하고, 안전 수칙을 철저히 지켜야 합니다.\n'
        '한편, 이번 비로 인해 일부 지역에서는 산사태 위험이 높아진 상태입니다.\n'
        '당국은 주민들에게 대피를 권고하며 추가 피해 예방에 총력을 기울이고 있습니다.\n'
        '현재까지 정확한 피해 규모는 조사 중이며, 정부는 추가 지원 대책을 논의할 예정입니다.',
  ),
];

const _seededKey = 'default_scripts_seeded';

/// 기본 원고를 한 번만 넣는다. 사용자가 지운 뒤에는 다시 넣지 않는다.
Future<void> seedDefaultScripts(Database db, ScriptRepository scripts) async {
  final done = await db.query('settings', where: 'key = ?', whereArgs: [_seededKey]);
  if (done.isNotEmpty) return;
  for (final s in defaultScripts) {
    await scripts.add(s);
  }
  await db.insert('settings', {'key': _seededKey, 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace);
}
