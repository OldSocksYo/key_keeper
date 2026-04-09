import 'package:hive/hive.dart';
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
}
