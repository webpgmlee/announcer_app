import 'package:announcer_app/analysis/read_aloud.dart';
import 'package:announcer_app/analysis/syllables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('한글은 글자당 1음절, 공백·문장부호 제외', () {
    expect(countSyllables('안녕하세요. 뉴스입니다!'), 10); // 안녕하세요(5) + 뉴스입니다(5)
  });
  test('숫자는 읽는 소리로', () {
    expect(readAloud('2026년'), '이천이십육년');
    expect(countSyllables('2026년'), 6);
    expect(countSyllables('3.5%'), 6); // 삼점오퍼센트
  });
  test('영어 약어는 알파벳 이름으로', () {
    expect(readAloud('KBS'), '케이비에스');
    expect(countSyllables('KBS'), 5);
  });
  test('빈 문자열은 0', () => expect(countSyllables(''), 0));
  test('분당 음절', () {
    expect(syllablesPerMinute(300, const Duration(seconds: 60)), 300);
    expect(syllablesPerMinute(150, const Duration(seconds: 30)), 300);
    expect(syllablesPerMinute(100, Duration.zero), 0);
  });

  group('수사 세부', () {
    test('0과 한 자리', () {
      expect(readAloud('0'), '영');
      expect(readAloud('7'), '칠');
    });
    test('십·백·천 앞의 일은 읽지 않는다', () {
      expect(readAloud('10'), '십');
      expect(readAloud('111'), '백십일');
      expect(readAloud('1000'), '천');
    });
    test('만 단위', () {
      expect(readAloud('10000'), '만');
      expect(readAloud('15000'), '만오천');
      expect(readAloud('300000'), '삼십만');
    });
    test('억·조 단위', () {
      expect(readAloud('100000000'), '일억');
      expect(readAloud('120000005'), '일억이천만오');
      expect(readAloud('1000000000000'), '일조');
    });
    test('천 단위 쉼표는 무시한다', () {
      expect(readAloud('1,500원'), '천오백원');
    });
    test('소수점 아래는 한 자리씩 읽는다', () {
      expect(readAloud('7.25'), '칠점이오');
      expect(readAloud('0.05'), '영점영오');
    });
  });

  group('기호와 영어', () {
    test('℃와 물결표', () {
      expect(readAloud('25℃'), '이십오도');
      expect(readAloud('3~5'), '삼에서오');
    });
    test('소문자도 알파벳 이름으로 읽는다', () {
      expect(readAloud('tv'), '티브이');
    });
    test('한글과 섞인 문장', () {
      expect(readAloud('KBS 9시 뉴스'), '케이비에스 구시 뉴스');
    });
  });

  test('숫자만 있는 원고도 음절 수가 0보다 크다 (Review Focus 4)', () {
    expect(countSyllables('2026 1 15'), greaterThan(0));
  });

  group('숫자 뒤 단위', () {
    test('길이·무게 단위는 우리말 이름으로 읽는다', () {
      expect(readAloud('100mm'), '백밀리미터');
      expect(readAloud('30cm'), '삼십센티미터');
      expect(readAloud('5km'), '오킬로미터');
      expect(readAloud('2kg'), '이킬로그램');
      expect(readAloud('3.5km'), '삼점오킬로미터');
      expect(readAloud('10 mm'), '십 밀리미터');
    });
    test('숫자 뒤가 아니면 알파벳으로 읽는다', () {
      expect(readAloud('mm'), '엠엠');
      expect(readAloud('KBS'), '케이비에스');
    });
    test('단위가 아닌 영어는 그대로 알파벳', () {
      expect(readAloud('5G'), '오지');
    });
  });
}
