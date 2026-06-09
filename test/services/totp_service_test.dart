import 'package:flutter_test/flutter_test.dart';
import 'package:key_keeper/services/totp_service.dart';

void main() {
  final service = TotpService();

  test('Base32 校验', () {
    expect(service.isValidBase32('JBSWY3DPEHPK3PXP'), isTrue);
    expect(service.isValidBase32('invalid!'), isFalse);
    expect(service.isValidBase32(''), isFalse);
  });

  test('生成 6 位验证码', () {
    final code = service.generateCode('JBSWY3DPEHPK3PXP');
    expect(code.length, 6);
    expect(int.tryParse(code), isNotNull);
  });

  test('剩余秒数在 1-30 之间', () {
    final remain = service.getRemainingSeconds();
    expect(remain, greaterThan(0));
    expect(remain, lessThanOrEqualTo(30));
  });
}
