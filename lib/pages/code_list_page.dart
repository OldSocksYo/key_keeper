import 'package:flutter/material.dart';
import 'package:key_keeper/models/account_entry.dart';
import 'package:key_keeper/services/account_service.dart';
import 'package:key_keeper/services/key_service.dart';
import 'package:key_keeper/services/totp_service.dart';
import 'package:key_keeper/widgets/account_icon.dart';
import 'package:key_keeper/widgets/totp_code_dialog.dart';

class CodeListPage extends StatefulWidget {
  const CodeListPage({
    super.key,
    required this.accountService,
    required this.keyService,
    required this.totpService,
    required this.searchNotifier,
  });

  final AccountService accountService;
  final KeyService keyService;
  final TotpService totpService;
  final ValueNotifier<String> searchNotifier;

  @override
  State<CodeListPage> createState() => CodeListPageState();
}

class CodeListPageState extends State<CodeListPage> {
  List<MapEntry<int, AccountEntry>> _list = [];

  @override
  void initState() {
    super.initState();
    widget.searchNotifier.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    widget.searchNotifier.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = await widget.accountService.getTotpList(keyword: widget.searchNotifier.value);
    if (!mounted) return;
    setState(() => _list = data);
  }

  Future<void> refreshNow() => _refresh();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        itemCount: _list.length,
        itemBuilder: (context, index) {
          final item = _list[index];
          return ListTile(
            leading: AccountIcon(typeText: item.value.typeText),
            title: Text(item.value.typeText),
            subtitle: Text(item.value.username),
            onTap: () async {
              final set = await widget.keyService.isUserKeySet();
              if (!set) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请先设置个人密钥')),
                );
                return;
              }
              if (!context.mounted) return;
              await showDialog<void>(
                context: context,
                builder: (_) => TotpCodeDialog(
                  username: item.value.username,
                  secret: item.value.totpSecret ?? '',
                  totpService: widget.totpService,
                ),
              );
            },
            onLongPress: () async {
              final delete = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('是否删除此账户？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('删除'),
                    ),
                  ],
                ),
              );
              if (delete == true) {
                await widget.accountService.deleteAccount(item.key);
                await _refresh();
              }
            },
          );
        },
      ),
    );
  }
}
