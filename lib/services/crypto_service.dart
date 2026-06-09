import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// 字段级加密：新数据使用 AES-256-GCM（随机 IV），兼容旧版 AES-192-CBC 固定 IV。
class CryptoService {
  /// 新格式密文前缀；带此前缀表示 AES-256-GCM + 随机 IV。
  static const String _gcmPrefix = 'g1:';

  /// 旧版固定 IV，仅用于解密历史数据，新写入不再使用。
  static const List<int> _legacyIvBytes = <int>[
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

  final Random _random = Random.secure();

  /// 判断密文是否已是 GCM 新格式（用于迁移时跳过已升级记录）。
  bool isNewFormat(String cipherText) => cipherText.startsWith(_gcmPrefix);

  /// 个人密钥 → 32 字节 AES-256 密钥（SHA256 全量截取）。
  enc.Key _buildAes256Key(String userKey) {
    final digest = sha256.convert(utf8.encode(userKey)).bytes;
    return enc.Key(Uint8List.fromList(digest));
  }

  enc.Key _buildLegacyAes192Key(String userKey) {
    final digest = sha256.convert(utf8.encode(userKey)).bytes;
    return enc.Key(Uint8List.fromList(digest.sublist(0, 24)));
  }

  Uint8List _randomNonce(int length) {
    return Uint8List.fromList(List<int>.generate(length, (_) => _random.nextInt(256)));
  }

  /// 加密明文；存储格式：g1: + base64(12字节IV + 密文含认证标签)。
  String encrypt(String userKey, String plainText) {
    final key = _buildAes256Key(userKey);
    final iv = enc.IV(_randomNonce(12));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    final payload = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
    return '$_gcmPrefix${base64Encode(payload)}';
  }

  /// 自动识别 GCM 新格式或旧版 CBC 密文并解密。
  String decrypt(String userKey, String cipherText) {
    if (isNewFormat(cipherText)) {
      return _decryptGcm(userKey, cipherText.substring(_gcmPrefix.length));
    }
    return _decryptLegacyCbc(userKey, cipherText);
  }

  String _decryptGcm(String userKey, String payloadBase64) {
    final payload = base64Decode(payloadBase64);
    if (payload.length < 13) {
      throw ArgumentError('Invalid GCM payload.');
    }
    final iv = enc.IV(Uint8List.sublistView(payload, 0, 12));
    final cipherBytes = Uint8List.sublistView(payload, 12);
    final key = _buildAes256Key(userKey);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    return encrypter.decrypt(enc.Encrypted(cipherBytes), iv: iv);
  }

  String _decryptLegacyCbc(String userKey, String cipherBase64) {
    final key = _buildLegacyAes192Key(userKey);
    final iv = enc.IV(Uint8List.fromList(_legacyIvBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(cipherBase64, iv: iv);
  }

  Uint8List encryptBytes(String userKey, Uint8List data) {
    final cipher = encrypt(userKey, base64Encode(data));
    return Uint8List.fromList(utf8.encode(cipher));
  }

  Uint8List decryptBytes(String userKey, Uint8List data) {
    final cipher = utf8.decode(data);
    final plain = decrypt(userKey, cipher);
    return Uint8List.fromList(base64Decode(plain));
  }
}
