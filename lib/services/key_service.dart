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

  Future<bool> verifyUserKey(String input) async {
    final normalized = input.trim();
    if (normalized.isEmpty) return false;
    final current = await getUserKey();
    return normalized == current;
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

  Future<void> changeAppMasterPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final hasOld = await isAppMasterPasswordSet();
    if (hasOld) {
      final ok = await verifyAppMasterPassword(oldPassword);
      if (!ok) {
        throw ArgumentError('旧主密码错误');
      }
    }
    await setAppMasterPassword(newPassword);
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

  /// 从快速选择中隐藏的类型（按小写去重）。
  Future<Set<String>> getHiddenAccountTypeSuggestions() async {
    final raw = await _secureStorage.read(key: AppConstants.hiddenAccountTypeSuggestionsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString().trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> hideAccountTypeSuggestion(String typeText) async {
    final normalized = typeText.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final hidden = await getHiddenAccountTypeSuggestions();
    hidden.add(normalized);
    await _secureStorage.write(
      key: AppConstants.hiddenAccountTypeSuggestionsKey,
      value: jsonEncode(hidden.toList()..sort()),
    );
  }

  Future<void> unhideAccountTypeSuggestion(String typeText) async {
    final normalized = typeText.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final hidden = await getHiddenAccountTypeSuggestions();
    if (!hidden.remove(normalized)) return;
    if (hidden.isEmpty) {
      await _secureStorage.delete(key: AppConstants.hiddenAccountTypeSuggestionsKey);
    } else {
      await _secureStorage.write(
        key: AppConstants.hiddenAccountTypeSuggestionsKey,
        value: jsonEncode(hidden.toList()..sort()),
      );
    }
  }

  String _randomBytesBase64(int len) {
    final bytes = List<int>.generate(len, (_) => _random.nextInt(256));
    return base64Encode(bytes);
  }

  String _sha256Hex(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }
}
