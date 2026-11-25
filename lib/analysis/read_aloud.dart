/// 원고의 숫자, 영어 알파벳, 일부 기호를 한글 읽는 소리로 바꾼다.
///
/// - 숫자는 한자어 수사(일, 십, 백, 천, 만, 억, 조)로 읽고, 소수점은 "점"으로 읽는다.
/// - 영어 알파벳은 글자 이름(A=에이 … Z=지)으로 읽는다.
/// - 기호: % → 퍼센트, ℃ → 도, ~ → 에서
/// - 숫자 바로 뒤의 단위(mm, cm, km, kg, mg, ml)는 우리말 이름으로 읽는다 (100mm → 백밀리미터).
/// - 고유어 수사(세 명, 다섯 시)는 v1 범위 밖이다.
String readAloud(String text) {
  // 천 단위 쉼표(1,500)를 먼저 지운다.
  var s = text.replaceAllMapped(
      RegExp(r'(?<=\d),(?=\d{3})'), (_) => '');
  // 숫자 뒤 단위는 알파벳으로 읽기 전에 바꾼다.
  s = s.replaceAllMapped(
      RegExp(r'(\d)(\s?)(mm|cm|km|kg|mg|ml)(?![A-Za-z])'),
      (m) => '${m[1]}${m[2]}${_units[m[3]]}');
  s = s.replaceAllMapped(RegExp(r'\d+(?:\.\d+)?'), (m) => _readNumber(m[0]!));
  s = s.replaceAllMapped(
      RegExp(r'[A-Za-z]'), (m) => _letters[m[0]!.toUpperCase()]!);
  _symbols.forEach((k, v) => s = s.replaceAll(k, v));
  return s;
}

const _symbols = {'%': '퍼센트', '℃': '도', '~': '에서'};

const _units = {
  'mm': '밀리미터',
  'cm': '센티미터',
  'km': '킬로미터',
  'kg': '킬로그램',
  'mg': '밀리그램',
  'ml': '밀리리터',
};

const _letters = {
  'A': '에이', 'B': '비', 'C': '씨', 'D': '디', 'E': '이', 'F': '에프',
  'G': '지', 'H': '에이치', 'I': '아이', 'J': '제이', 'K': '케이', 'L': '엘',
  'M': '엠', 'N': '엔', 'O': '오', 'P': '피', 'Q': '큐', 'R': '알',
  'S': '에스', 'T': '티', 'U': '유', 'V': '브이', 'W': '더블유', 'X': '엑스',
  'Y': '와이', 'Z': '지',
};

const _digits = ['영', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];

String _readNumber(String n) {
  final parts = n.split('.');
  final whole = _readInteger(parts[0]);
  if (parts.length == 1) return whole;
  final frac = parts[1].split('').map((d) => _digits[int.parse(d)]).join();
  return '$whole점$frac';
}

String _readInteger(String digits) {
  final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (trimmed == '0') return '영';
  const bigUnits = ['', '만', '억', '조', '경'];
  final groups = <String>[];
  for (var end = trimmed.length; end > 0; end -= 4) {
    groups.insert(0, trimmed.substring(end - 4 < 0 ? 0 : end - 4, end));
  }
  if (groups.length > bigUnits.length) {
    // 너무 큰 수는 한 자리씩 읽는다.
    return trimmed.split('').map((d) => _digits[int.parse(d)]).join();
  }
  final out = StringBuffer();
  for (var i = 0; i < groups.length; i++) {
    final value = int.parse(groups[i]);
    if (value == 0) continue;
    final unit = bigUnits[groups.length - 1 - i];
    // "일만"은 "만"으로 읽는다. 억·조는 "일억", "일조"로 읽는다.
    final g = (value == 1 && unit == '만') ? '' : _readGroup(value);
    out.write('$g$unit');
  }
  return out.toString();
}

/// 0~9999를 읽는다. 십·백·천 앞의 "일"은 생략한다.
String _readGroup(int value) {
  const units = ['천', '백', '십', ''];
  final s = value.toString().padLeft(4, '0');
  final out = StringBuffer();
  for (var i = 0; i < 4; i++) {
    final d = int.parse(s[i]);
    if (d == 0) continue;
    if (d == 1 && units[i].isNotEmpty) {
      out.write(units[i]);
    } else {
      out.write('${_digits[d]}${units[i]}');
    }
  }
  return out.toString();
}
