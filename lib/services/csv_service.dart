import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:key_keeper/models/account_entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:key_keeper/services/account_service.dart';
import 'package:key_keeper/services/crypto_service.dart';
import 'package:key_keeper/services/key_service.dart';

/// CSV 导出目的地。
enum CsvExportDestination {
  /// 系统分享面板（云盘、邮件等）。
  systemShare,
  /// 系统文件保存对话框。
  saveToFile,
}

/// 账号 CSV 导入导出；加密导出时用 [CryptoService.encryptBytes] 保护整文件。
class CsvService {
  CsvService(this._accountService, this._keyService, this._cryptoService);

  final AccountService _accountService;
  final KeyService _keyService;
  final CryptoService _cryptoService;

  static const _csvHeader = <String>[
    'typeText',
    'username',
    'password',
    'totpSecret',
  ];

  static String _exportTimeStamp() {
    final d = DateTime.now();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${p2(d.month)}${p2(d.day)}${p2(d.hour)}${p2(d.minute)}';
  }

  static List<dynamic> _entryToRow(AccountEntry e) => <dynamic>[
        e.typeText,
        e.username,
        e.passwordSecret ?? '',
        e.totpSecret ?? '',
      ];

  Future<void> exportPlain(CsvExportDestination destination) async {
    final list = await _accountService.getAccountList(scope: DecryptScope.full);
    final rows = <List<dynamic>>[
      _csvHeader,
      ...list.map((e) => _entryToRow(e.value)),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(utf8.encode(csv));
    await _dispatchExport(
      destination: destination,
      bytes: bytes,
      fileName: '${_exportTimeStamp()}_account.csv',
      saveDialogTitle: '导出明文 CSV',
      shareMimeType: 'text/csv',
    );
  }

  Future<void> exportEncrypted(CsvExportDestination destination) async {
    final list = await _accountService.getAccountList(scope: DecryptScope.full);
    final rows = list.map((e) => _entryToRow(e.value)).toList();
    final csv = const ListToCsvConverter().convert(rows);
    final userKey = await _keyService.getUserKey();
    final encrypted = _cryptoService.encryptBytes(
      userKey,
      Uint8List.fromList(utf8.encode(csv)),
    );
    await _dispatchExport(
      destination: destination,
      bytes: encrypted,
      fileName: '${_exportTimeStamp()}_encryptedAccount.csv',
      saveDialogTitle: '导出加密 CSV',
      shareMimeType: 'application/octet-stream',
    );
  }

  Future<void> _dispatchExport({
    required CsvExportDestination destination,
    required Uint8List bytes,
    required String fileName,
    required String saveDialogTitle,
    required String shareMimeType,
  }) async {
    switch (destination) {
      case CsvExportDestination.systemShare:
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        try {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path, mimeType: shareMimeType)],
              title: 'KeyKeeper 导出',
            ),
          );
        } finally {
          try {
            await file.delete();
          } catch (_) {}
        }
      case CsvExportDestination.saveToFile:
        await FilePicker.platform.saveFile(
          dialogTitle: saveDialogTitle,
          fileName: fileName,
          bytes: bytes,
        );
    }
  }

  Future<void> importPlain() async {
    final bytes = await _pickFileBytes();
    if (bytes == null) return;
    final rows = const CsvToListConverter().convert(utf8.decode(bytes));
    await _importRows(rows, skipHeader: true);
  }

  Future<void> importEncrypted() async {
    final bytes = await _pickFileBytes();
    if (bytes == null) return;
    final userKey = await _keyService.getUserKey();
    final plain = _cryptoService.decryptBytes(userKey, bytes);
    final rows = const CsvToListConverter().convert(utf8.decode(plain));
    await _importRows(rows, skipHeader: false);
  }

  Future<Uint8List?> _pickFileBytes() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    return picked?.files.single.bytes;
  }

  /// 批量导入 CSV 行：预建去重集合 + 一次性 batch 写入，避免逐条全表扫描。
  Future<void> _importRows(
    List<List<dynamic>> rows, {
    required bool skipHeader,
  }) async {
    if (rows.isEmpty) return;
    final start =
        skipHeader && rows.first.isNotEmpty && rows.first.first == 'typeText'
            ? 1
            : 0;

    final existingAccounts = await _accountService.getAccountList(scope: DecryptScope.list);
    // 用 typeText + username 小写组合去重，\x00 分隔避免碰撞。
    final existingSet = <String>{
      for (final e in existingAccounts)
        '${e.value.typeText.trim().toLowerCase()}\x00${e.value.username.trim().toLowerCase()}',
    };

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final batch = <AccountEntry>[];
    for (var i = start; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 4) continue;
      final typeText = row[0].toString();
      final username = row[1].toString();
      final dedupKey =
          '${typeText.trim().toLowerCase()}\x00${username.trim().toLowerCase()}';
      if (existingSet.contains(dedupKey)) continue;
      existingSet.add(dedupKey);
      final password = row[2].toString();
      final totpSecret = row[3].toString();
      batch.add(AccountEntry(
        typeText: typeText,
        username: username,
        passwordSecret: password.isEmpty ? null : password,
        totpSecret: totpSecret.isEmpty ? null : totpSecret,
        updateTime: now,
      ));
    }
    await _accountService.addAccountsBatch(batch);
  }
}
