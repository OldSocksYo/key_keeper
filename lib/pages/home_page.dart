import 'package:flutter/material.dart';
import 'package:key_keeper/main.dart';
import 'package:key_keeper/pages/account_detail_page.dart';
import 'package:key_keeper/pages/account_list_page.dart';
import 'package:key_keeper/pages/mine_page.dart';

/// 解锁后的主页：底部双 Tab（账号列表 / 我的），通过 [IndexedStack] 保持 Tab 状态。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  /// 搜索关键词，传给 [AccountListPage] 做筛选（带 300ms 防抖）。
  final _accountSearchNotifier = ValueNotifier<String>('');
  /// 手动刷新信号：新增/编辑/导入完成后递增，驱动列表重拉。
  final _accountListBump = ValueNotifier<int>(0);

  @override
  void dispose() {
    _searchCtrl.dispose();
    _accountSearchNotifier.dispose();
    _accountListBump.dispose();
    super.dispose();
  }

  bool get _isListTab => _index == 0;

  String get _title {
    if (_searching) return '';
    switch (_index) {
      case 0:
        return '账号';
      default:
        return '我的';
    }
  }

  void _onSearchChanged(String value) {
    if (_index == 0) {
      _accountSearchNotifier.value = value;
    }
  }

  Future<void> _handleAdd() async {
    if (_index == 0) {
      final ok = await appKeyService.isUserKeySet();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先设置个人密钥')));
        return;
      }
      if (!mounted) return;
      // 详情/编辑页用 Navigator.push 而非 go_router，以便后台恢复时保留未保存的编辑状态。
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AccountDetailPage(
            args: AccountDetailArgs(mode: AccountDetailMode.insert),
            accountService: appAccountService,
          ),
        ),
      );
      if (!mounted) return;
      if (saved == true) {
        _searchCtrl.clear();
        _accountSearchNotifier.value = '';
        if (_searching) {
          setState(() => _searching = false);
        }
      }
      _accountListBump.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(hintText: '请输入账户类型或用户名'),
              )
            : Text(_title),
        actions: [
          if (_isListTab)
            IconButton(
              onPressed: () {
                setState(() {
                  _searching = !_searching;
                  if (!_searching) {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  }
                });
              },
              icon: Icon(_searching ? Icons.close : Icons.search),
            ),
          if (_isListTab)
            IconButton(
              onPressed: _handleAdd,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      // IndexedStack 同时保留两个 Tab 的子树，切换 Tab 不销毁列表状态。
      body: IndexedStack(
        index: _index,
        children: [
          AccountListPage(
            accountService: appAccountService,
            searchNotifier: _accountSearchNotifier,
            listBump: _accountListBump,
          ),
          MinePage(
            keyService: appKeyService,
            csvService: appCsvService,
            accountService: appAccountService,
            listBump: _accountListBump,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
            _searching = false;
            _searchCtrl.clear();
            _accountSearchNotifier.value = '';
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.account_box), label: '账号'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
