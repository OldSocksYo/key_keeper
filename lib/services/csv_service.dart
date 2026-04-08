import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:key_keeper/models/account_entry.dart';
import 'package:key_keeper/services/account_service.dart';
import 'package:key_keeper/services/crypto_service.dart';
import 'package:key_keeper/services/key_service.dart';

class CsvService {
  CsvService(this._accountService, this._keyService, this._cryptoService);

  final AccountService _accountService;
  final KeyService _keyService;
  final CryptoService _cryptoService;

  Future<void> exportPlain() async {
    final list = await _accountService.getAccountList();
    final rows = <List<dynamic>>[
      <String>['typeText', 'username', 'password', 'totpSecret'],
      ...list.map((e) => <dynamic>[
            e.value.typeText,
            e.value.username,
            e.value.passwordSecret ?? '',
            e.value.totpSecret ?? '',
          ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save plain CSV',
      fileName: 'account.csv',
    );
    if (path == null) return;
    await File(path).writeAsString(csv);
  }

  Future<void> exportEncrypted() async {
    final list = await _accountService.getAccountList();
    final rows = list.map((e) => <dynamic>[
          e.value.typeText,
          e.value.username,
          e.value.passwordSecret ?? '',
          e.value.totpSecret ?? '',
        ]).toList();
    final csv = const ListToCsvConverter().convert(rows);
    final userKey = await _keyService.getUserKey();
    final encrypted = _cryptoService.encryptBytes(userKey, Uint8List.fromList(utf8.encode(csv)));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save encrypted CSV',
      fileName: 'encryptedAccount.csv',
    );
    if (path == null) return;
    await File(path).writeAsBytes(encrypted, flush: true);
  }

  Future<void> importPlain() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return;
    final text = utf8.decode(bytes);
    final rows = const CsvToListConverter().convert(text);
    if (rows.isEmpty) return;
    final start = rows.first.isNotEmpty && rows.first.first == 'typeText' ? 1 : 0;
    for (var i = start; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 4) continue;
      final typeText = row[0].toString();
      final username = row[1].toString();
      final password = row[2].toString();
      final totpSecret = row[3].toString();
      if (await _accountService.accountExists(typeText, username)) continue;
      await _accountService.addAccount(AccountEntry(
        typeText: typeText,
        username: username,
        passwordSecret: password.isEmpty ? null : password,
        totpSecret: totpSecret.isEmpty ? null : totpSecret,
        updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ));
    }
  }

  Future<void> importEncrypted() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return;
    final userKey = await _keyService.getUserKey();
    final plain = _cryptoService.decryptBytes(userKey, bytes);
    final rows = const CsvToListConverter().convert(utf8.decode(plain));
    if (rows.isEmpty) return;
    for (final row in rows) {
      if (row.length < 4) continue;
      final typeText = row[0].toString();
      final username = row[1].toString();
      final password = row[2].toString();
      final totpSecret = row[3].toString();
      if (await _accountService.accountExists(typeText, username)) continue;
      await _accountService.addAccount(AccountEntry(
        typeText: typeText,
        username: username,
        passwordSecret: password.isEmpty ? null : password,
        totpSecret: totpSecret.isEmpty ? null : totpSecret,
        updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ));
    }
  }
}
