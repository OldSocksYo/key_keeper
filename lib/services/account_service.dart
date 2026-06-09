import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:key_keeper/common/constants.dart';
import 'package:key_keeper/models/account_entry.dart';
import 'package:key_keeper/services/crypto_service.dart';
import 'package:key_keeper/services/key_service.dart';

/// 控制列表加载时解密哪些敏感字段。
enum DecryptScope {
  /// 列表模式：仅解密 TOTP，不解密密码。
  list,

  /// 完整解密：密码与 TOTP 均解密。
  full,
}

/// 账号 CRUD 与 Hive 交互的唯一入口；负责调用 [CryptoService] 加解密敏感字段。
class AccountService {
  AccountService(this._box, this._cryptoService, this._keyService);

  final Box<AccountEntry> _box;
  final CryptoService _cryptoService;
  final KeyService _keyService;

  /// 数据变更计数器，列表页监听此值以自动刷新（导入、删除、编辑后递增）。
  final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

  void _notifyChanged() {
    dataRevision.value++;
  }

  Future<void> addAccount(AccountEntry account) async {
    final userKey = await _keyService.getUserKey();
    await _addAccountWithKey(userKey, account);
    _notifyChanged();
  }

  Future<void> addAccountsBatch(List<AccountEntry> accounts) async {
    if (accounts.isEmpty) return;
    final userKey = await _keyService.getUserKey();
    for (final account in accounts) {
      await _addAccountWithKey(userKey, account);
    }
    _notifyChanged();
  }

  /// 按「类型 + 用户名」去重：已存在则合并更新，空字段保留原值。
  Future<void> _addAccountWithKey(String userKey, AccountEntry account) async {
    final existingKey = _findKey(account.typeText, account.username);
    AccountEntry? existing;
    if (existingKey != null) {
      final raw = _box.get(existingKey);
      if (raw != null) {
        existing = _decryptEntryWith(
          userKey,
          raw,
          scope: DecryptScope.full,
        );
      }
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
    _notifyChanged();
  }

  Future<void> deleteAccount(int key) async {
    await _box.delete(key);
    _notifyChanged();
  }

  Future<AccountEntry?> getAccount(int key) async {
    final raw = _box.get(key);
    if (raw == null) return null;
    final userKey = await _keyService.getUserKey();
    return _decryptEntryWith(userKey, raw, scope: DecryptScope.full);
  }

  /// 默认 [DecryptScope.list] 只解密 TOTP，列表页不触碰密码明文以提升性能。
  Future<List<MapEntry<int, AccountEntry>>> getAccountList({
    String? keyword,
    DecryptScope scope = DecryptScope.list,
  }) async {
    final entries = <MapEntry<int, AccountEntry>>[
      for (final e in _box.toMap().entries) MapEntry(e.key as int, e.value),
    ];
    entries.sort((a, b) => b.value.updateTime.compareTo(a.value.updateTime));
    final q = keyword?.trim().toLowerCase() ?? '';
    final filtered = entries.where((entry) {
      final v = entry.value;
      return q.isEmpty ||
          v.typeText.toLowerCase().contains(q) ||
          v.username.toLowerCase().contains(q);
    }).toList();

    final userKey = await _keyService.getUserKey();
    return [
      for (final entry in filtered)
        MapEntry(entry.key, _decryptEntryWith(userKey, entry.value, scope: scope)),
    ];
  }

  Future<List<MapEntry<int, AccountEntry>>> getTotpList({String? keyword}) async {
    final all = await getAccountList(keyword: keyword, scope: DecryptScope.list);
    return all.where((entry) => entry.value.hasTotp).toList();
  }

  Future<bool> accountExists(String typeText, String username) async {
    final typeTextLower = typeText.trim().toLowerCase();
    final usernameLower = username.trim().toLowerCase();
    return _box.values.any((item) =>
        item.typeText.trim().toLowerCase() == typeTextLower &&
        item.username.trim().toLowerCase() == usernameLower);
  }

  /// 将旧版 CBC 密文迁移为 GCM 格式。
  Future<int> migrateLegacyEncryptionIfNeeded() async {
    if (!await _keyService.isUserKeySet()) return 0;
    final userKey = await _keyService.getUserKey();
    var migrated = 0;
    final updates = <int, AccountEntry>{};

    for (final entry in _box.toMap().entries) {
      final key = entry.key as int;
      final value = entry.value;
      var nextPassword = value.passwordSecret;
      var nextTotp = value.totpSecret;
      var changed = false;

      final rawPassword = (value.passwordSecret ?? '').trim();
      if (rawPassword.isNotEmpty && !_cryptoService.isNewFormat(rawPassword)) {
        final plain = _safeDecrypt(userKey, rawPassword);
        if (plain != null) {
          nextPassword = _cryptoService.encrypt(userKey, plain);
          changed = true;
        }
      }

      final rawTotp = (value.totpSecret ?? '').trim();
      if (rawTotp.isNotEmpty && !_cryptoService.isNewFormat(rawTotp)) {
        final plain = _safeDecrypt(userKey, rawTotp);
        if (plain != null) {
          nextTotp = _cryptoService.encrypt(userKey, plain);
          changed = true;
        }
      }

      if (changed) {
        updates[key] = AccountEntry(
          typeText: value.typeText,
          username: value.username,
          passwordSecret: nextPassword,
          totpSecret: nextTotp,
          updateTime: value.updateTime,
        );
        migrated++;
      }
    }

    if (updates.isNotEmpty) {
      await _box.putAll(updates);
      _notifyChanged();
    }
    return migrated;
  }

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
          rawPassword.isEmpty ? null : _safeDecrypt(oldNormalized, rawPassword);
      final decryptedTotp = rawTotp.isEmpty ? null : _safeDecrypt(oldNormalized, rawTotp);

      final nextPassword = (decryptedPassword ?? '').isEmpty
          ? null
          : _cryptoService.encrypt(newNormalized, decryptedPassword!);
      final nextTotp = (decryptedTotp ?? '').isEmpty
          ? null
          : _cryptoService.encrypt(newNormalized, decryptedTotp!);

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
      // 新密钥持久化失败时回滚账户数据，避免「库已换钥但密钥未保存」的不一致状态。
      await _box.putAll(original);
      rethrow;
    }
    _notifyChanged();
  }

  Future<List<String>> getAccountTypeSuggestions() async {
    final hidden = await _keyService.getHiddenAccountTypeSuggestions();
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
    return [
      for (final e in result)
        if (!hidden.contains(e.trim().toLowerCase())) e,
    ];
  }

  Future<void> removeAccountTypeFromQuickPick(String typeText) =>
      _keyService.hideAccountTypeSuggestion(typeText);

  Future<void> restoreAccountTypeToQuickPick(String typeText) =>
      _keyService.unhideAccountTypeSuggestion(typeText);

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

  AccountEntry _decryptEntryWith(
    String userKey,
    AccountEntry encrypted, {
    required DecryptScope scope,
  }) {
    String? password;
    if (scope == DecryptScope.full) {
      password = (encrypted.passwordSecret ?? '').isEmpty
          ? null
          : _safeDecrypt(userKey, encrypted.passwordSecret!);
    }

    final totp = (encrypted.totpSecret ?? '').isEmpty
        ? null
        : _safeDecrypt(userKey, encrypted.totpSecret!);

    return AccountEntry(
      typeText: encrypted.typeText,
      username: encrypted.username,
      passwordSecret: password,
      totpSecret: totp,
      updateTime: encrypted.updateTime,
    );
  }

  /// 单条解密失败返回 null，避免一条损坏记录导致整表加载崩溃。
  String? _safeDecrypt(String userKey, String cipher) {
    try {
      return _cryptoService.decrypt(userKey, cipher);
    } catch (_) {
      return null;
    }
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
