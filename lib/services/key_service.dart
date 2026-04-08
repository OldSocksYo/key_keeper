import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
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

  Future<bool> isAppMasterPasswordSet() async {
    final value = await _secureStorage.read(key: AppConstants.appMasterPasswordHashName);
    return value != null && value.isNotEmpty;
  }

  Future<void> setAppMasterPassword(String password) async {
    final normalized = password.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Password cannot be empty.');
    }
    final hash = _sha256Hex(normalized);
    await _secureStorage.write(key: AppConstants.appMasterPasswordHashName, value: hash);
  }

  Future<bool> verifyAppMasterPassword(String password) async {
    final stored = await _secureStorage.read(key: AppConstants.appMasterPasswordHashName);
    if (stored == null || stored.isEmpty) return false;
    final incoming = _sha256Hex(password.trim());
    return incoming == stored;
  }

  Future<String> getUnlockMethod() async {
    final value = await _secureStorage.read(key: AppConstants.unlockMethodName);
    if (value == AppConstants.unlockMethodMasterPassword) {
      return AppConstants.unlockMethodMasterPassword;
    }
    return AppConstants.unlockMethodBiometric;
  }

  Future<void> setUnlockMethod(String method) async {
    if (method != AppConstants.unlockMethodBiometric &&
        method != AppConstants.unlockMethodMasterPassword) {
      throw ArgumentError('Unsupported unlock method: $method');
    }
    await _secureStorage.write(key: AppConstants.unlockMethodName, value: method);
  }

  String _randomBytesBase64(int len) {
    final bytes = List<int>.generate(len, (_) => _random.nextInt(256));
    return base64Encode(bytes);
  }

  String _sha256Hex(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }
}
