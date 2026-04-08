import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class CryptoService {
  static const List<int> _fixedIvBytes = <int>[
    0x12,
    0x34,
    0x33,
    0x33,
    0x90,
    0xcd,
    0xcd,
    0xef,
    0xfe,
    0xdc,
    0xba,
    0x98,
    0x34,
    0x54,
    0x32,
    0x10,
  ];

  enc.Key _buildAes192Key(String userKey) {
    final digest = sha256.convert(utf8.encode(userKey)).bytes;
    return enc.Key(Uint8List.fromList(digest.sublist(0, 24)));
  }

  String encrypt(String userKey, String plainText) {
    final key = _buildAes192Key(userKey);
    final iv = enc.IV(Uint8List.fromList(_fixedIvBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  String decrypt(String userKey, String cipherBase64) {
    final key = _buildAes192Key(userKey);
    final iv = enc.IV(Uint8List.fromList(_fixedIvBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(cipherBase64, iv: iv);
  }

  Uint8List encryptBytes(String userKey, Uint8List data) {
    final cipher = encrypt(userKey, base64Encode(data));
    return Uint8List.fromList(base64Decode(cipher));
  }

  Uint8List decryptBytes(String userKey, Uint8List data) {
    final plain = decrypt(userKey, base64Encode(data));
    return Uint8List.fromList(base64Decode(plain));
  }
}
