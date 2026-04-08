import 'package:flutter/material.dart';
import 'package:key_keeper/models/account_entry.dart';
import 'package:key_keeper/pages/account_detail_page.dart';
import 'package:key_keeper/services/account_service.dart';
import 'package:key_keeper/widgets/account_icon.dart';

class AccountListPage extends StatefulWidget {
  const AccountListPage({
    super.key,
    required this.accountService,
    required this.searchNotifier,
  });

  final AccountService accountService;
  final ValueNotifier<String> searchNotifier;

  @override
  State<AccountListPage> createState() => AccountListPageState();
}

class AccountListPageState extends State<AccountListPage> {
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
    final data = await widget.accountService.getAccountList(keyword: widget.searchNotifier.value);
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
            trailing: Wrap(
              spacing: 6,
              children: [
                if (item.value.hasPassword) const Chip(label: Text('密码')),
                if (item.value.hasTotp) const Chip(label: Text('TOTP')),
              ],
            ),
            onTap: () async {
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountDetailPage(
                    args: AccountDetailArgs(mode: AccountDetailMode.view, key: item.key),
                    accountService: widget.accountService,
                  ),
                ),
              );
              if (ok == true) await _refresh();
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
