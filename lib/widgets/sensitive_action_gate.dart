import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:key_keeper/common/constants.dart';
import 'package:key_keeper/main.dart';
import 'package:local_auth/local_auth.dart';

/// 敏感操作前二次验证：生物识别或主密码。
Future<bool> requestSensitiveActionConfirmation(
  BuildContext context, {
  required String reason,
}) async {
  final unlockMethod = await appKeyService.getUnlockMethod();
  final masterSet = await appKeyService.isAppMasterPasswordSet();
  final canUseBiometric = unlockMethod == AppConstants.unlockMethodBiometric &&
      await localAuth.isDeviceSupported();

  if (canUseBiometric) {
    try {
      final ok = await localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
      if (ok) return true;
    } on PlatformException {
      // 生物识别失败时回退到主密码。
    }
  }

  if (!masterSet) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先设置主密码以确认敏感操作')),
    );
    return false;
  }

  if (!context.mounted) return false;
  var password = '';
  var obscure = true;
  var error = '';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('安全确认'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason),
            const SizedBox(height: 12),
            TextField(
              obscureText: obscure,
              autofocus: true,
              onChanged: (value) => setDialogState(() {
                password = value;
                error = '';
              }),
              onSubmitted: (_) async {
                final ok = await appKeyService.verifyAppMasterPassword(password);
                if (!context.mounted) return;
                if (ok) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() => error = '主密码错误');
                }
              },
              decoration: InputDecoration(
                labelText: '输入主密码',
                errorText: error.isEmpty ? null : error,
                suffixIcon: IconButton(
                  onPressed: () => setDialogState(() => obscure = !obscure),
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await appKeyService.verifyAppMasterPassword(password);
              if (!context.mounted) return;
              if (ok) {
                Navigator.pop(context, true);
              } else {
                setDialogState(() => error = '主密码错误');
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    ),
  );
  return confirmed == true;
}

Future<bool> confirmRiskyExport(BuildContext context) async {
  if (!context.mounted) return false;
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('明文导出风险'),
      content: const Text(
        '明文 CSV 包含所有账号密码与 TOTP 密钥，任何获得该文件的人均可读取。\n\n'
        '建议优先使用加密导出。确定要继续吗？',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('继续导出'),
        ),
      ],
    ),
  );
  if (proceed != true || !context.mounted) return false;
  return requestSensitiveActionConfirmation(
    context,
    reason: '确认导出明文账号数据',
  );
}
