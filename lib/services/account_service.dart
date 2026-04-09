import 'package:hive/hive.dart';
import 'package:key_keeper/common/constants.dart';
import 'package:key_keeper/models/account_entry.dart';
import 'package:key_keeper/services/crypto_service.dart';
import 'package:key_keeper/services/key_service.dart';

class AccountService {
  AccountService(this._box, this._cryptoService, this._keyService);

  final Box<AccountEntry> _box;
  final CryptoService _cryptoService;
  final KeyService _keyService;

  Future<void> addAccount(AccountEntry account) async {
    final userKey = await _keyService.getUserKey();
    final existingKey = _findKey(account.typeText, account.username);
    AccountEntry? existing;
    if (existingKey != null) {
      existing = await getAccount(existingKey);
    }

    final mergedPassword =
        (account.passwordSecret ?? '').trim().isNotEmpty ? account.passwordSecret : existing?.passwordSecret;
    final mergedTotp =
        (account.totpSecret ?? '').trim().isNotEmpty ? account.totpSecret : existing?.totpSecret;

    final encryptedPassword = (mergedPassword ?? '').trim().isNotEmpty
        ? _cryptoService.encrypt(userKey, mergedPassword!.trim())
        : null;
    final encryptedTotp = (mergedTotp ?? '').trim().isNotEmpty
        ? _cryptoService.encrypt(userKey, mergedTotp!.trim())
        : null;
    final toSave = AccountEntry(
      typeText: account.typeText,
      username: account.username,
      passwordSecret: encryptedPassword,
      totpSecret: encryptedTotp,
      updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    if (existingKey != null) {
      await _box.put(existingKey, toSave);
    } else {
      await _box.add(toSave);
    }
  }

  Future<void> updateAccount(int key, AccountEntry account) async {
    final userKey = await _keyService.getUserKey();
    final encryptedPassword = (account.passwordSecret ?? '').trim().isEmpty
        ? null
        : _cryptoService.encrypt(userKey, account.passwordSecret!.trim());
    final encryptedTotp = (account.totpSecret ?? '').trim().isEmpty
        ? null
        : _cryptoService.encrypt(userKey, account.totpSecret!.trim());
    final toSave = AccountEntry(
      typeText: account.typeText,
      username: account.username,
      passwordSecret: encryptedPassword,
      totpSecret: encryptedTotp,
      updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    await _box.put(key, toSave);
  }

  Future<void> deleteAccount(int key) => _box.delete(key);

  Future<AccountEntry?> getAccount(int key) async {
    final raw = _box.get(key);
    if (raw == null) return null;
    return _decryptEntry(raw);
  }

  Future<List<MapEntry<int, AccountEntry>>> getAccountList({String? keyword}) async {
    // 不可对 Hive toMap().entries 使用 .cast<MapEntry<int,...>>().toList() 再 sort：
    // CastList 在 sort 时会按元素强转，导致 MapEntry<dynamic,...> 运行时失败。
    final entries = <MapEntry<int, AccountEntry>>[
      for (final e in _box.toMap().entries) MapEntry(e.key as int, e.value),
    ];
    entries.sort((a, b) => b.value.updateTime.compareTo(a.value.updateTime));
    final filtered = entries.where((entry) {
      final v = entry.value;
      final q = keyword?.trim().toLowerCase() ?? '';
      final keywordOk =
          q.isEmpty || v.typeText.toLowerCase().contains(q) || v.username.toLowerCase().contains(q);
      return keywordOk;
    }).toList();

    final out = <MapEntry<int, AccountEntry>>[];
    for (final entry in filtered) {
      out.add(MapEntry(entry.key, await _decryptEntry(entry.value)));
    }
    return out;
  }

  Future<List<MapEntry<int, AccountEntry>>> getTotpList({String? keyword}) async {
    final all = await getAccountList(keyword: keyword);
    return all.where((entry) => entry.value.hasTotp).toList();
  }

  Future<bool> accountExists(String typeText, String username) async {
    final typeTextLower = typeText.trim().toLowerCase();
    final usernameLower = username.trim().toLowerCase();
    return _box.values.any((item) =>
        item.typeText.trim().toLowerCase() == typeTextLower &&
        item.username.trim().toLowerCase() == usernameLower);
  }

  /// 使用新个人密钥对全部账户字段进行重加密。
  /// 若持久化新密钥失败，会回滚到账户重加密前状态。
  Future<void> rotateUserKey({
    required String oldUserKey,
    required String newUserKey,
    required Future<void> Function() persistNewKey,
  }) async {
    final oldNormalized = oldUserKey.trim();
    final newNormalized = newUserKey.trim();
    if (oldNormalized.isEmpty || newNormalized.isEmpty) {
      throw ArgumentError('密钥不能为空');
    }

    final original = <int, AccountEntry>{
      for (final e in _box.toMap().entries) e.key as int: _copyEntry(e.value),
    };

    final reEncrypted = <int, AccountEntry>{};
    for (final entry in original.entries) {
      final value = entry.value;
      final rawPassword = (value.passwordSecret ?? '').trim();
      final rawTotp = (value.totpSecret ?? '').trim();

      final decryptedPassword =
          rawPassword.isEmpty ? null : _cryptoService.decrypt(oldNormalized, rawPassword);
      final decryptedTotp = rawTotp.isEmpty ? null : _cryptoService.decrypt(oldNormalized, rawTotp);

      final nextPassword =
          (decryptedPassword ?? '').isEmpty ? null : _cryptoService.encrypt(newNormalized, decryptedPassword!);
      final nextTotp = (decryptedTotp ?? '').isEmpty ? null : _cryptoService.encrypt(newNormalized, decryptedTotp!);

      reEncrypted[entry.key] = AccountEntry(
        typeText: value.typeText,
        username: value.username,
        passwordSecret: nextPassword,
        totpSecret: nextTotp,
        updateTime: value.updateTime,
      );
    }

    await _box.putAll(reEncrypted);
    try {
      await persistNewKey();
    } catch (_) {
      await _box.putAll(original);
      rethrow;
    }
  }

  /// 返回账户类型建议：预置类型 + 已保存账户中的自定义类型（去重）。
  Future<List<String>> getAccountTypeSuggestions() async {
    final result = <String>[...AppConstants.accountTypePresets];
    final exists = result.map((e) => e.toLowerCase()).toSet();
    final entries = _box.toMap().entries.toList();
    entries.sort((a, b) => (b.value.updateTime).compareTo(a.value.updateTime));
    for (final entry in entries) {
      final typeText = entry.value.typeText.trim();
      if (typeText.isEmpty) continue;
      final lower = typeText.toLowerCase();
      if (exists.contains(lower)) continue;
      exists.add(lower);
      result.add(typeText);
    }
    return result;
  }

  int? _findKey(String typeText, String username) {
    final typeTextLower = typeText.trim().toLowerCase();
    final usernameLower = username.trim().toLowerCase();
    for (final entry in _box.toMap().entries) {
      final item = entry.value;
      if (item.typeText.trim().toLowerCase() == typeTextLower &&
          item.username.trim().toLowerCase() == usernameLower) {
        return entry.key as int;
      }
    }
    return null;
  }

  Future<AccountEntry> _decryptEntry(AccountEntry encrypted) async {
    final userKey = await _keyService.getUserKey();
    final password = (encrypted.passwordSecret ?? '').isEmpty
        ? null
        : _cryptoService.decrypt(userKey, encrypted.passwordSecret!);
    final totp = (encrypted.totpSecret ?? '').isEmpty
        ? null
        : _cryptoService.decrypt(userKey, encrypted.totpSecret!);
    return AccountEntry(
      typeText: encrypted.typeText,
      username: encrypted.username,
      passwordSecret: password,
      totpSecret: totp,
      updateTime: encrypted.updateTime,
    );
  }

  AccountEntry _copyEntry(AccountEntry source) {
    return AccountEntry(
      typeText: source.typeText,
      username: source.username,
      passwordSecret: source.passwordSecret,
      totpSecret: source.totpSecret,
      updateTime: source.updateTime,
    );
  }
}
