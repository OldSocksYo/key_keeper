import 'package:flutter/material.dart';
import 'package:key_keeper/common/constants.dart';
import 'package:key_keeper/services/csv_service.dart';
import 'package:key_keeper/services/key_service.dart';
import 'package:key_keeper/widgets/private_key_dialog.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key, required this.keyService, required this.csvService});

  final KeyService keyService;
  final CsvService csvService;

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  String _unlockMethod = AppConstants.unlockMethodBiometric;

  @override
  void initState() {
    super.initState();
    _loadUnlockMethod();
  }

  Future<void> _loadUnlockMethod() async {
    final method = await widget.keyService.getUnlockMethod();
    if (!mounted) return;
    setState(() => _unlockMethod = method);
  }

  String get _unlockMethodText =>
      _unlockMethod == AppConstants.unlockMethodMasterPassword ? '主密码' : '生物识别';

  Future<void> _chooseUnlockMethod() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('生物识别'),
              trailing: _unlockMethod == AppConstants.unlockMethodBiometric
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, AppConstants.unlockMethodBiometric),
            ),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('主密码'),
              trailing: _unlockMethod == AppConstants.unlockMethodMasterPassword
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, AppConstants.unlockMethodMasterPassword),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await widget.keyService.setUnlockMethod(selected);
    if (!mounted) return;
    setState(() => _unlockMethod = selected);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('解锁方式已更新，下次解锁生效')),
    );
  }

  Future<bool> _ensureKey(BuildContext context) async {
    final set = await widget.keyService.isUserKeySet();
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
          leading: const Icon(Icons.lock_outline),
          title: const Text('解锁方式'),
          subtitle: Text(_unlockMethodText),
          trailing: const Icon(Icons.chevron_right),
          onTap: _chooseUnlockMethod,
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.vpn_key),
          title: const Text('设置个人密钥'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDialog(
            context: context,
            builder: (_) => PrivateKeyDialog(keyService: widget.keyService),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: const Text('加密导出'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            if (!await _ensureKey(context)) return;
            await widget.csvService.exportEncrypted();
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
            await widget.csvService.importEncrypted();
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
            await widget.csvService.exportPlain();
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
            await widget.csvService.importPlain();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入完成')));
          },
        ),
      ],
    );
  }
}
