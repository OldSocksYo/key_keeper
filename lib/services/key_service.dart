import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:key_keeper/common/constants.dart';
import 'package:key_keeper/services/crypto_service.dart';

class KeyService {
  KeyService(this._secureStorage, this._cryptoService);

  final FlutterSecureStorage _secureStorage;
  final CryptoService _cryptoService;
  final Random _random = Random.secure();

  Future<String> ensureHiveKey() async {
    final value = await _secureStorage.read(key: AppConstants.hiveEncryptionKeyName);
    if (value != null && value.isNotEmpty) return value;
    final generated = _randomBytesBase64(32);
    await _secureStorage.write(key: AppConstants.hiveEncryptionKeyName, value: generated);
    return generated;
  }

  Future<void> _ensureInitSecret() async {
    final value = await _secureStorage.read(key: AppConstants.initSecretName);
    if (value != null && value.isNotEmpty) return;
    final generated = _randomBytesBase64(32);
    await _secureStorage.write(key: AppConstants.initSecretName, value: generated);
  }

  Future<bool> isUserKeySet() async {
    final value = await _secureStorage.read(key: AppConstants.userKeySetName);
    return value == 'true';
  }

  Future<void> saveUserKey(String plainKey) async {
    await _ensureInitSecret();
    final initSecret = await _secureStorage.read(key: AppConstants.initSecretName);
    if (initSecret == null || initSecret.isEmpty) {
      throw StateError('Init secret not found.');
    }
    final encrypted = _cryptoService.encrypt(initSecret, plainKey);
    await _secureStorage.write(key: AppConstants.userKeyEncryptedName, value: encrypted);
    await _secureStorage.write(key: AppConstants.userKeySetName, value: 'true');
  }

  Future<String> getUserKey() async {
    await _ensureInitSecret();
    final initSecret = await _secureStorage.read(key: AppConstants.initSecretName);
    final encrypted = await _secureStorage.read(key: AppConstants.userKeyEncryptedName);
    if (initSecret == null || encrypted == null || encrypted.isEmpty) {
      throw StateError('User key is not configured.');
    }
    return _cryptoService.decrypt(initSecret, encrypted);
  }

  String _randomBytesBase64(int len) {
    final bytes = List<int>.generate(len, (_) => _random.nextInt(256));
    return base64Encode(bytes);
  }
}
