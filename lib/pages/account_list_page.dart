import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:key_keeper/main.dart';
import 'package:key_keeper/models/account_entry.dart';
import 'package:key_keeper/pages/account_detail_page.dart';
import 'package:key_keeper/services/account_service.dart';
import 'package:key_keeper/widgets/account_icon.dart';
import 'package:key_keeper/widgets/confirm_delete_dialog.dart';
import 'package:key_keeper/widgets/totp_display.dart';

class AccountListPage extends StatefulWidget {
  const AccountListPage({
    super.key,
    required this.accountService,
    required this.searchNotifier,
    required this.listBump,
  });

  final AccountService accountService;
  final ValueNotifier<String> searchNotifier;
  final ValueNotifier<int> listBump;

  @override
  State<AccountListPage> createState() => AccountListPageState();
}

class AccountListPageState extends State<AccountListPage> {
  List<MapEntry<int, AccountEntry>> _list = [];
  Timer? _searchDebounce;
  String _pendingKeyword = '';

  late final VoidCallback _onListBump;

  @override
  void initState() {
    super.initState();
    _onListBump = _refresh;
    widget.searchNotifier.addListener(_onSearchChanged);
    widget.listBump.addListener(_onListBump);
    widget.accountService.dataRevision.addListener(_onListBump);
    _pendingKeyword = widget.searchNotifier.value;
    _refresh();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    widget.searchNotifier.removeListener(_onSearchChanged);
    widget.listBump.removeListener(_onListBump);
    widget.accountService.dataRevision.removeListener(_onListBump);
    super.dispose();
  }

  void _onSearchChanged() {
    _pendingKeyword = widget.searchNotifier.value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _refresh);
  }

  Future<void> _refresh() async {
    final data = await widget.accountService.getAccountList(keyword: _pendingKeyword);
    if (!mounted) return;
    setState(() => _list = data);
  }

  Future<void> refreshNow() => _refresh();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: _list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('暂无账号，点击右上角 + 添加')),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _list.length,
              itemBuilder: (context, index) {
                final item = _list[index];
                final colorScheme = Theme.of(context).colorScheme;
                return Slidable(
                  key: ValueKey('account_${item.key}'),
                  endActionPane: ActionPane(
                    motion: const BehindMotion(),
                    extentRatio: 0.26,
                    children: [
                      SlidableAction(
                        onPressed: (_) async {
                          final delete = await showConfirmDeleteDialog(context);
                          if (!context.mounted || delete != true) return;
                          await widget.accountService.deleteAccount(item.key);
                          await _refresh();
                        },
                        backgroundColor: colorScheme.errorContainer,
                        foregroundColor: colorScheme.onErrorContainer,
                        icon: Icons.delete_outline,
                        label: '删除',
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: AccountIcon(typeText: item.value.typeText),
                    title: Text(item.value.typeText),
                    subtitle: Text(item.value.username),
                    trailing: item.value.hasTotp
                        ? TotpListTrailing(
                            secret: item.value.totpSecret ?? '',
                            totpService: appTotpService,
                          )
                        : null,
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
                  ),
                );
              },
            ),
    );
  }
}
