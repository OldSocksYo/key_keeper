import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256，用于主密码派生。
Uint8List pbkdf2HmacSha256({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  required int keyLength,
}) {
  if (iterations < 1) {
    throw ArgumentError('iterations must be >= 1');
  }
  if (keyLength < 1) {
    throw ArgumentError('keyLength must be >= 1');
  }

  final hmac = Hmac(sha256, password);
  final blockCount = (keyLength + 31) ~/ 32;
  final result = BytesBuilder(copy: false);

  for (var block = 1; block <= blockCount; block++) {
    final blockIndex = Uint8List(4)
      ..buffer.asByteData().setUint32(0, block, Endian.big);
    var u = hmac.convert([...salt, ...blockIndex]).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    result.add(t);
  }

  return Uint8List.fromList(result.takeBytes().sublist(0, keyLength));
}

String randomSaltBase64({int length = 16}) {
  final random = Random.secure();
  final bytes = List<int>.generate(length, (_) => random.nextInt(256));
  return base64Encode(bytes);
}
