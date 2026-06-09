import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:key_keeper/services/crypto_service.dart';

void main() {
  final crypto = CryptoService();
  const userKey = 'test-user-key-12345';

  test('GCM 加解密往返', () {
    const plain = 'my-secret-password';
    final cipher = crypto.encrypt(userKey, plain);
    expect(crypto.isNewFormat(cipher), isTrue);
    expect(crypto.decrypt(userKey, cipher), plain);
  });

  test('相同明文产生不同密文（随机 IV）', () {
    const plain = 'same-plaintext';
    final a = crypto.encrypt(userKey, plain);
    final b = crypto.encrypt(userKey, plain);
    expect(a, isNot(equals(b)));
    expect(crypto.decrypt(userKey, a), plain);
    expect(crypto.decrypt(userKey, b), plain);
  });

  test('错误密钥解密失败', () {
    final cipher = crypto.encrypt(userKey, 'secret');
    expect(() => crypto.decrypt('wrong-key', cipher), throwsA(anything));
  });

  test('字节加解密往返', () {
    final data = Uint8List.fromList([1, 2, 3, 4, 5]);
    final encrypted = crypto.encryptBytes(userKey, data);
    final decrypted = crypto.decryptBytes(userKey, encrypted);
    expect(decrypted, data);
  });
}
