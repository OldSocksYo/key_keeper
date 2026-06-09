import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:key_keeper/common/constants.dart';
import 'package:key_keeper/services/crypto_service.dart';
import 'package:key_keeper/utils/pbkdf2.dart';
import 'package:key_keeper/utils/secure_compare.dart';

class KeyService {
  KeyService(this._secureStorage, this._cryptoService);

  final FlutterSecureStorage _secureStorage;
  final CryptoService _cryptoService;
  final Random _random = Random.secure();

  String? _cachedUserKey;

  static const int _pbkdf2Iterations = 600000;
  static const String _pbkdf2Prefix = 'pbkdf2:';

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
    _cachedUserKey = plainKey;
  }

  Future<String> getUserKey() async {
    if (_cachedUserKey != null) return _cachedUserKey!;
    await _ensureInitSecret();
    final initSecret = await _secureStorage.read(key: AppConstants.initSecretName);
    final encrypted = await _secureStorage.read(key: AppConstants.userKeyEncryptedName);
    if (initSecret == null || encrypted == null || encrypted.isEmpty) {
      throw StateError('User key is not configured.');
    }
    final plain = _cryptoService.decrypt(initSecret, encrypted);
    if (!_cryptoService.isNewFormat(encrypted)) {
      final upgraded = _cryptoService.encrypt(initSecret, plain);
      await _secureStorage.write(key: AppConstants.userKeyEncryptedName, value: upgraded);
    }
    _cachedUserKey = plain;
    return plain;
  }

  /// 解锁成功后预热个人密钥缓存，减少列表加载时的 Secure Storage 读取。
  Future<void> warmUserKeyCache() async {
    if (_cachedUserKey != null) return;
    if (!await isUserKeySet()) return;
    await getUserKey();
  }

  void clearSessionCache() {
    _cachedUserKey = null;
  }

  Future<bool> verifyUserKey(String input) async {
    final normalized = input.trim();
    if (normalized.isEmpty) return false;
    final current = await getUserKey();
    return secureCompareStrings(normalized, current);
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
    final hash = _hashMasterPassword(normalized);
    await _secureStorage.write(key: AppConstants.appMasterPasswordHashName, value: hash);
  }

  Future<bool> verifyAppMasterPassword(String password) async {
    final stored = await _secureStorage.read(key: AppConstants.appMasterPasswordHashName);
    if (stored == null || stored.isEmpty) return false;
    final normalized = password.trim();
    if (_isPbkdf2Hash(stored)) {
      return _verifyPbkdf2Hash(normalized, stored);
    }
    final legacyOk = secureCompareStrings(_sha256Hex(normalized), stored);
    if (legacyOk) {
      await setAppMasterPassword(normalized);
    }
    return legacyOk;
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

  String _hashMasterPassword(String password) {
    final salt = randomSaltBase64();
    final hash = pbkdf2HmacSha256(
      password: utf8.encode(password),
      salt: base64Decode(salt),
      iterations: _pbkdf2Iterations,
      keyLength: 32,
    );
    return '$_pbkdf2Prefix$_pbkdf2Iterations:$salt:${base64Encode(hash)}';
  }

  bool _isPbkdf2Hash(String stored) => stored.startsWith(_pbkdf2Prefix);

  bool _verifyPbkdf2Hash(String password, String stored) {
    final body = stored.substring(_pbkdf2Prefix.length);
    final parts = body.split(':');
    if (parts.length != 3) return false;
    final iterations = int.tryParse(parts[0]);
    if (iterations == null || iterations < 1) return false;
    final salt = base64Decode(parts[1]);
    final expected = base64Decode(parts[2]);
    final actual = pbkdf2HmacSha256(
      password: utf8.encode(password),
      salt: salt,
      iterations: iterations,
      keyLength: expected.length,
    );
    return secureCompareBytes(actual, expected);
  }

  String _randomBytesBase64(int len) {
    final bytes = List<int>.generate(len, (_) => _random.nextInt(256));
    return base64Encode(bytes);
  }

  String _sha256Hex(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }
}
