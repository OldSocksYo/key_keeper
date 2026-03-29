import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("KeyKeeper 密码管理"),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: () => context.go('/unlock'), // 回到解锁页
          ),
        ],
      ),
      body: const Center(
        child: Text("密码管理首页（后续扩展）"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 后续添加：新增密码
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}