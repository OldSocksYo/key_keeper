import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';

// 导入后续要创建的页面（先占位，后面创建）
import 'pages/unlock_page.dart';
import 'pages/home_page.dart';

// 全局常量
const String hiveBoxName = 'password_box'; // Hive 数据库名称
const String secureKeyName = 'encryption_key'; // 加密密钥存储键名
final FlutterSecureStorage secureStorage = FlutterSecureStorage(); // 系统安全存储
final LocalAuthentication localAuth = LocalAuthentication(); // 生物识别实例

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化 Hive 数据库
  await Hive.initFlutter();
  // 2. 获取/生成加密密钥（首次启动生成，后续复用）
  String? encryptionKey = await secureStorage.read(key: secureKeyName);
  if (encryptionKey == null) {
    // 首次启动：生成随机 32 位密钥（AES-256 要求）
    encryptionKey = List.generate(32, (index) => Random().nextInt(256)).toString();
    await secureStorage.write(key: secureKeyName, value: encryptionKey);
  }
  // 3. 打开加密的 Hive 数据库
  final encryptionCipher = HiveAesCipher(encryptionKey.codeUnits);
  await Hive.openBox(hiveBoxName, encryptionCipher: encryptionCipher);

  // 4. 启动应用
  runApp(const MyApp());
}

// 路由配置
final GoRouter _router = GoRouter(
  initialLocation: '/unlock', // 启动页：解锁页
  routes: [
    GoRoute(
      path: '/unlock',
      builder: (context, state) => const UnlockPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KeyKeeper',
      theme: ThemeData(primarySwatch: Colors.blue),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}