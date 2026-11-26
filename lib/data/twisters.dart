// 퍼펙트딕션 잰말놀이 도전 원고.
// 1~2단계는 예부터 전해 오는 잰말놀이(누구나 쓰는 공유 문장)이고, 3단계는 뉴스 낭독 연습용으로
// 새로 쓴 문장이다. 실존 인물·기업 이름은 쓰지 않았다.

class Twister {
  const Twister({required this.id, required this.stage, required this.title, required this.body});

  /// 기록을 저장하는 고정 아이디 (바꾸면 기록이 이어지지 않는다).
  final String id;
  final int stage;
  final String title;
  final String body;
}

const twisters = [
  // 1단계: 짧고 익숙한 잰말놀이
  Twister(
      id: 'ganjang',
      stage: 1,
      title: '간장공장 공장장',
      body: '간장 공장 공장장은 강 공장장이고, 된장 공장 공장장은 공 공장장이다.'),
  Twister(
      id: 'girin',
      stage: 1,
      title: '기린 그림',
      body: '내가 그린 기린 그림은 긴 기린 그림이고, 네가 그린 기린 그림은 안 긴 기린 그림이다.'),
  Twister(
      id: 'cheolchang',
      stage: 1,
      title: '경찰청 철창살',
      body: '경찰청 철창살은 외철창살이냐 쌍철창살이냐.'),
  Twister(
      id: 'kongkkakji',
      stage: 1,
      title: '콩깍지',
      body: '저기 저 콩깍지는 깐 콩깍지인가 안 깐 콩깍지인가.'),
  Twister(
      id: 'yangjangjeom',
      stage: 1,
      title: '양장점',
      body: '한양 양장점 옆 한영 양장점, 한영 양장점 옆 한양 양장점.'),

  // 2단계: 받침과 된소리가 이어지는 잰말놀이
  Twister(
      id: 'kkangtong',
      stage: 2,
      title: '깡통',
      body: '상표 붙인 큰 깡통은 깐 깡통인가, 안 깐 깡통인가.'),
  Twister(
      id: 'chanson',
      stage: 2,
      title: '샹송 쇼',
      body: '신진 샹송 가수의 신춘 샹송 쇼, 신춘 샹송 쇼의 신진 샹송 가수.'),
  Twister(
      id: 'patjuk',
      stage: 2,
      title: '팥죽과 콩죽',
      body: '앞집 팥죽은 붉은 팥 풋팥죽이고, 뒷집 콩죽은 햇콩 단콩 콩죽이다.'),
  Twister(
      id: 'sot',
      stage: 2,
      title: '솥장수',
      body: '작년에 온 솥장수는 새 솥장수이고, 금년에 온 솥장수는 헌 솥장수다.'),
  Twister(
      id: 'beotkkot',
      stage: 2,
      title: '벚꽃놀이',
      body: '박범복 군은 밤벚꽃놀이를 가고, 방범복 군은 낮벚꽃놀이를 간다.'),

  // 3단계: 뉴스 문장처럼 길고 발음이 꼬이는 문장
  Twister(
      id: 'saengsan',
      stage: 3,
      title: '생산 공장 공장장',
      body: '생산 공장 공장장과 생산 관리 과장이 신상품 생산 계획을 상세히 상의했습니다.'),
  Twister(
      id: 'cheongso',
      stage: 3,
      title: '철창살 청소',
      body: '철도청 청사 창살 청소 담당 청소년 실습생이 철창살을 깨끗이 청소했습니다.'),
  Twister(
      id: 'teukheo',
      stage: 3,
      title: '특허 허가과',
      body: '특허 허가과 허가과장 허 과장은 특허 허가 서류를 꼼꼼히 확인했습니다.'),
  Twister(
      id: 'gwangwang',
      stage: 3,
      title: '관광 경쟁력',
      body: '관광 공사 곽 관광과장이 국제 관광 경쟁력 강화 방안을 발표했습니다.'),
  Twister(
      id: 'gyeongje',
      stage: 3,
      title: '경제 정책 점검',
      body: '정부는 경제 정책 점검 회의에서 수출 증진 정책과 재정 집행 점검 결과를 정리했습니다.'),
];

/// 단계별 목표 속도 (1분당 음절).
double stagePace(int stage) => switch (stage) {
      1 => 300,
      2 => 350,
      _ => 400,
    };

/// 다음 단계를 여는 데 필요한 앞 단계 별 수.
const starsToUnlock = 5;

/// 한 단계에서 모은 별 (도전마다 최고 별).
int starsInStage(int stage, Map<String, int> bestStars) => twisters
    .where((t) => t.stage == stage)
    .fold(0, (sum, t) => sum + (bestStars[t.id] ?? 0));

/// 1단계는 늘 열려 있고, 다음 단계는 앞 단계에서 별 5개를 모으면 열린다.
bool stageUnlocked(int stage, Map<String, int> bestStars) =>
    stage <= 1 || starsInStage(stage - 1, bestStars) >= starsToUnlock;
