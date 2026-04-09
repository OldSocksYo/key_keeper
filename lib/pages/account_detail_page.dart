import 'dart:async';

import 'package:flutter/material.dart';
import 'package:key_keeper/common/constants.dart';
import 'package:key_keeper/main.dart';
import 'package:key_keeper/models/account_entry.dart';
import 'package:key_keeper/services/account_service.dart';
import 'package:key_keeper/widgets/account_icon.dart';

class AccountDetailArgs {
  AccountDetailArgs({required this.mode, this.key});

  final AccountDetailMode mode;
  final int? key;
}

enum AccountDetailMode { view, insert }

class AccountDetailPage extends StatefulWidget {
  const AccountDetailPage({super.key, required this.args, required this.accountService});

  final AccountDetailArgs args;
  final AccountService accountService;

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  final _typeCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _totpCtrl = TextEditingController();
  bool _editing = false;
  bool _passwordObscure = true;
  bool _totpObscure = true;
  Timer? _timer;
  String _totpPreview = '------';
  int _totpRemain = 30;
  List<String> _typeOptions = [...AppConstants.accountTypePresets];

  bool get _isInsert => widget.args.mode == AccountDetailMode.insert;
  bool get _isReadOnly => !_isInsert && !_editing;

  @override
  void initState() {
    super.initState();
    _totpCtrl.addListener(_updateTotpPreview);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTotpPreview());
    _loadTypeOptions();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _typeCtrl.dispose();
    _userCtrl.dispose();
    _passwordCtrl.dispose();
    _totpCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isInsert) return;
    final key = widget.args.key;
    if (key == null) return;
    final account = await widget.accountService.getAccount(key);
    if (account == null || !mounted) return;
    setState(() {
      _typeCtrl.text = account.typeText;
      _userCtrl.text = account.username;
      _passwordCtrl.text = account.passwordSecret ?? '';
      _totpCtrl.text = account.totpSecret ?? '';
    });
    _updateTotpPreview();
  }

  Future<void> _loadTypeOptions() async {
    final options = await widget.accountService.getAccountTypeSuggestions();
    if (!mounted) return;
    setState(() => _typeOptions = options);
  }

  Future<void> _addTypeOption() async {
    var input = '';
    final added = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新增账号类型'),
          content: TextField(
            autofocus: true,
            onChanged: (value) => setDialogState(() => input = value),
            onSubmitted: (value) {
              final text = value.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context, text);
              }
            },
            decoration: const InputDecoration(
              hintText: '例如：知乎 / 小红书 / Steam',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: input.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, input.trim()),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    final value = (added ?? '').trim();
    if (value.isEmpty) return;
    final exists = _typeOptions.any((e) => e.toLowerCase() == value.toLowerCase());
    if (!exists) {
      setState(() => _typeOptions = [..._typeOptions, value]);
    }
    _typeCtrl.text = value;
  }

  Future<void> _save() async {
    final typeText = _typeCtrl.text.trim();
    final username = _userCtrl.text.trim();
    if (typeText.isEmpty || username.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写账户类型和用户名')),
      );
      return;
    }
    final account = AccountEntry(
      typeText: typeText,
      username: username,
      passwordSecret: _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
      totpSecret: _totpCtrl.text.trim().isEmpty ? null : _totpCtrl.text.trim(),
      updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    if (_isInsert) {
      await widget.accountService.addAccount(account);
    } else {
      final key = widget.args.key;
      if (key == null) return;
      await widget.accountService.updateAccount(key, account);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _updateTotpPreview() {
    final raw = _totpCtrl.text.trim().toUpperCase();
    if (raw.isEmpty || !appTotpService.isValidBase32(raw)) {
      if (!mounted) return;
      setState(() {
        _totpPreview = '------';
        _totpRemain = appTotpService.getRemainingSeconds();
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _totpPreview = appTotpService.generateCode(raw);
      _totpRemain = appTotpService.getRemainingSeconds();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isInsert ? '新增账户' : (_editing ? '编辑账户' : '账户详情')),
        actions: [
          if (!_isInsert && !_editing)
            IconButton(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit),
            ),
          if (_isInsert || _editing)
            IconButton(
              onPressed: _save,
              icon: const Icon(Icons.check),
            ),
          if (_editing && !_isInsert)
            IconButton(
              onPressed: () async {
                setState(() => _editing = false);
                await _load();
              },
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              AccountIcon(typeText: _typeCtrl.text.isEmpty ? 'default' : _typeCtrl.text, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _typeCtrl,
                  readOnly: _isReadOnly,
                  decoration: const InputDecoration(labelText: '账户类型'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userCtrl,
            readOnly: _isReadOnly,
            decoration: const InputDecoration(labelText: '用户名'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            readOnly: _isReadOnly,
            obscureText: _passwordObscure,
            decoration: InputDecoration(
              labelText: '登录密码（可选）',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _passwordObscure = !_passwordObscure),
                icon: Icon(_passwordObscure ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _totpCtrl,
            readOnly: _isReadOnly,
            obscureText: _totpObscure,
            decoration: InputDecoration(
              labelText: 'TOTP 密钥（可选）',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _totpObscure = !_totpObscure),
                icon: Icon(_totpObscure ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('实时 TOTP 预览'),
                      const SizedBox(height: 6),
                      Text(
                        _totpPreview,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          value: _totpRemain / 30,
                          strokeWidth: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${_totpRemain}s'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_totpCtrl.text.trim().isNotEmpty &&
              !appTotpService.isValidBase32(_totpCtrl.text.trim().toUpperCase()))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'TOTP 密钥格式无效（应为 Base32）',
                style: TextStyle(color: Colors.red),
              ),
            ),
          if (_isInsert || _editing) ...[
            const SizedBox(height: 16),
            const Text('快速选择类型'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addTypeOption,
                icon: const Icon(Icons.add),
                label: const Text('新增类型'),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _typeOptions
                  .map((e) => ChoiceChip(
                        label: Text(e),
                        selected: _typeCtrl.text == e,
                        onSelected: (_) => setState(() => _typeCtrl.text = e),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
