import 'package:flutter/material.dart';
import 'package:key_keeper/common/constants.dart';
import 'package:key_keeper/models/account_entry.dart';
import 'package:key_keeper/services/account_service.dart';
import 'package:key_keeper/services/totp_service.dart';

class CodeAccountAddSheet extends StatefulWidget {
  const CodeAccountAddSheet({
    super.key,
    required this.accountService,
    required this.totpService,
    required this.onAdded,
  });

  final AccountService accountService;
  final TotpService totpService;
  final VoidCallback onAdded;

  @override
  State<CodeAccountAddSheet> createState() => _CodeAccountAddSheetState();
}

class _CodeAccountAddSheetState extends State<CodeAccountAddSheet> {
  final _typeCtrl = TextEditingController(text: AppConstants.codeAccountType.first);
  final _userCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _typeCtrl.dispose();
    _userCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _typeCtrl.text,
            items: AppConstants.codeAccountType
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => _typeCtrl.text = v ?? _typeCtrl.text,
            decoration: const InputDecoration(labelText: '账户类型'),
          ),
          TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: '用户名')),
          TextField(
            controller: _secretCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'TOTP 密钥',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final username = _userCtrl.text.trim();
                  final secret = _secretCtrl.text.trim().toUpperCase();
                  if (username.isEmpty || secret.isEmpty) return;
                  if (!widget.totpService.isValidBase32(secret)) return;
                  await widget.accountService.addAccount(AccountEntry(
                    typeText: _typeCtrl.text.trim(),
                    username: username,
                    passwordSecret: null,
                    totpSecret: secret,
                    updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  ));
                  widget.onAdded();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('确认'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
