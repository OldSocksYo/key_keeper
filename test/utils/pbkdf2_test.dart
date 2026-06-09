import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:key_keeper/utils/pbkdf2.dart';
import 'package:key_keeper/utils/secure_compare.dart';

void main() {
  test('PBKDF2 相同输入产生相同输出', () {
    final salt = utf8.encode('fixed-salt');
    final a = pbkdf2HmacSha256(
      password: utf8.encode('password'),
      salt: salt,
      iterations: 1000,
      keyLength: 32,
    );
    final b = pbkdf2HmacSha256(
      password: utf8.encode('password'),
      salt: salt,
      iterations: 1000,
      keyLength: 32,
    );
    expect(secureCompareBytes(a, b), isTrue);
  });

  test('不同密码产生不同哈希', () {
    final salt = utf8.encode('salt');
    final a = pbkdf2HmacSha256(
      password: utf8.encode('password-a'),
      salt: salt,
      iterations: 1000,
      keyLength: 32,
    );
    final b = pbkdf2HmacSha256(
      password: utf8.encode('password-b'),
      salt: salt,
      iterations: 1000,
      keyLength: 32,
    );
    expect(secureCompareBytes(a, b), isFalse);
  });
}
