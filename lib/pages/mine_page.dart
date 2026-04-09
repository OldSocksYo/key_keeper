import 'package:flutter/material.dart';
import 'package:key_keeper/common/constants.dart';
import 'package:key_keeper/services/account_service.dart';
import 'package:key_keeper/services/csv_service.dart';
import 'package:key_keeper/services/key_service.dart';
import 'package:key_keeper/widgets/private_key_dialog.dart';

class MinePage extends StatefulWidget {
  const MinePage({
    super.key,
    required this.keyService,
    required this.csvService,
    required this.accountService,
  });

  final KeyService keyService;
  final CsvService csvService;
  final AccountService accountService;

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

  Future<void> _changeUserKey() async {
    final set = await widget.keyService.isUserKeySet();
    if (!set) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先设置个人密钥')),
      );
      return;
    }

    if (!mounted) return;
    var oldKey = '';
    var newKey = '';
    var confirmKey = '';
    var obscureOld = true;
    var obscureNew = true;
    var obscureConfirm = true;
    var saving = false;
    var dialogError = '';

    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canSubmit = oldKey.trim().isNotEmpty &&
              newKey.trim().isNotEmpty &&
              confirmKey.trim().isNotEmpty &&
              newKey == confirmKey &&
              !saving;

          Future<void> submit() async {
            if (!canSubmit) return;
            setDialogState(() {
              saving = true;
              dialogError = '';
            });
            try {
              final verifyOk = await widget.keyService.verifyUserKey(oldKey);
              if (!verifyOk) {
                setDialogState(() {
                  saving = false;
                  dialogError = '旧个人密钥错误，请重试';
                });
                return;
              }

              await widget.accountService.rotateUserKey(
                oldUserKey: oldKey,
                newUserKey: newKey,
                persistNewKey: () => widget.keyService.saveUserKey(newKey),
              );

              if (!context.mounted) return;
              Navigator.pop(context, true);
            } catch (_) {
              setDialogState(() {
                saving = false;
                dialogError = '密钥更新失败，请稍后重试';
              });
            }
          }

          return AlertDialog(
            title: const Text('修改个人密钥'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '保存后会对所有账户进行全量重加密，请勿中断操作。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    obscureText: obscureOld,
                    onChanged: (value) => setDialogState(() => oldKey = value),
                    decoration: InputDecoration(
                      labelText: '旧个人密钥',
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                        icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    obscureText: obscureNew,
                    onChanged: (value) => setDialogState(() => newKey = value),
                    decoration: InputDecoration(
                      labelText: '新个人密钥',
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    obscureText: obscureConfirm,
                    onChanged: (value) => setDialogState(() => confirmKey = value),
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: '确认新个人密钥',
                      errorText: confirmKey.isEmpty || newKey == confirmKey ? null : '两次输入不一致',
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                  if (dialogError.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        dialogError,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: canSubmit ? submit : null,
                child: Text(saving ? '处理中...' : '保存'),
              ),
            ],
          );
        },
      ),
    );

    if (changed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('个人密钥更新成功，账户已完成重加密')),
    );
  }

  Future<void> _changeMasterPassword() async {
    final hasSet = await widget.keyService.isAppMasterPasswordSet();
    if (!mounted) return;
    var oldPassword = '';
    var newPassword = '';
    var confirmPassword = '';
    var obscureOld = true;
    var obscureNew = true;
    var obscureConfirm = true;
    var dialogError = '';
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canSubmit = (hasSet ? oldPassword.trim().isNotEmpty : true) &&
              newPassword.trim().isNotEmpty &&
              confirmPassword.trim().isNotEmpty &&
              newPassword == confirmPassword &&
              !saving;

          Future<void> submit() async {
            if (!canSubmit) return;
            setDialogState(() {
              saving = true;
              dialogError = '';
            });
            try {
              await widget.keyService.changeAppMasterPassword(
                oldPassword: oldPassword,
                newPassword: newPassword,
              );
              if (!context.mounted) return;
              Navigator.pop(context, true);
            } catch (e) {
              final isOldPasswordError = e is ArgumentError && e.message == '旧主密码错误';
              setDialogState(() {
                dialogError = isOldPasswordError ? '旧主密码错误，请重试' : '主密码保存失败，请稍后再试';
                saving = false;
              });
            }
          }

          return AlertDialog(
            title: Text(hasSet ? '修改主密码' : '设置主密码'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSet)
                    TextField(
                      obscureText: obscureOld,
                      onChanged: (value) => setDialogState(() => oldPassword = value),
                      decoration: InputDecoration(
                        labelText: '旧主密码',
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                          icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                    ),
                  if (hasSet) const SizedBox(height: 12),
                  TextField(
                    obscureText: obscureNew,
                    onChanged: (value) => setDialogState(() => newPassword = value),
                    decoration: InputDecoration(
                      labelText: '新主密码',
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    obscureText: obscureConfirm,
                    onChanged: (value) => setDialogState(() => confirmPassword = value),
                    onSubmitted: (_) {
                      submit();
                    },
                    decoration: InputDecoration(
                      labelText: '确认新主密码',
                      errorText:
                          confirmPassword.isEmpty || newPassword == confirmPassword ? null : '两次输入不一致',
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                  if (dialogError.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        dialogError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: canSubmit ? submit : null,
                child: Text(saving ? '保存中...' : '保存'),
              ),
            ],
          );
        },
      ),
    );

    if (changed != true) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hasSet ? '主密码修改成功' : '主密码设置成功')),
    );
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
          title: const Text('查看个人密钥'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDialog(
            context: context,
            builder: (_) => PrivateKeyDialog(keyService: widget.keyService),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.key),
          title: const Text('修改个人密钥'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _changeUserKey,
        ),
        ListTile(
          leading: const Icon(Icons.password),
          title: const Text('修改主密码'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _changeMasterPassword,
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
