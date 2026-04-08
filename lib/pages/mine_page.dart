import 'package:flutter/material.dart';
import 'package:key_keeper/services/csv_service.dart';
import 'package:key_keeper/services/key_service.dart';
import 'package:key_keeper/widgets/private_key_dialog.dart';

class MinePage extends StatelessWidget {
  const MinePage({super.key, required this.keyService, required this.csvService});

  final KeyService keyService;
  final CsvService csvService;

  Future<bool> _ensureKey(BuildContext context) async {
    final set = await keyService.isUserKeySet();
    if (set) return true;
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先设置个人密钥')),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.vpn_key),
          title: const Text('设置个人密钥'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDialog(
            context: context,
            builder: (_) => PrivateKeyDialog(keyService: keyService),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: const Text('加密导出'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            if (!await _ensureKey(context)) return;
            await csvService.exportEncrypted();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导出完成')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.file_download),
          title: const Text('加密导入'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            if (!await _ensureKey(context)) return;
            await csvService.importEncrypted();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入完成')));
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.upload),
          title: const Text('明文导出'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            if (!await _ensureKey(context)) return;
            await csvService.exportPlain();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导出完成')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('明文导入'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            if (!await _ensureKey(context)) return;
            await csvService.importPlain();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入完成')));
          },
        ),
      ],
    );
  }
}
