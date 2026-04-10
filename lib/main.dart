import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:key_keeper/common/constants.dart';
import 'package:key_keeper/models/account_entry.dart';
import 'package:key_keeper/pages/home_page.dart';
import 'package:key_keeper/pages/unlock_page.dart';
import 'package:key_keeper/services/account_service.dart';
import 'package:key_keeper/services/crypto_service.dart';
import 'package:key_keeper/services/csv_service.dart';
import 'package:key_keeper/services/key_service.dart';
import 'package:key_keeper/services/totp_service.dart';
import 'package:local_auth/local_auth.dart';

final FlutterSecureStorage secureStorage = FlutterSecureStorage();
final LocalAuthentication localAuth = LocalAuthentication();

late final CryptoService appCryptoService;
late final KeyService appKeyService;
late final AccountService appAccountService;
late final TotpService appTotpService;
late final CsvService appCsvService;

final GoRouter appRouter = GoRouter(
  initialLocation: '/unlock',
  routes: [
    GoRoute(path: '/unlock', builder: (context, state) => const UnlockPage()),
    GoRoute(path: '/home', builder: (context, state) => const HomePage()),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(AccountEntryAdapter());

  appCryptoService = CryptoService();
  appKeyService = KeyService(secureStorage, appCryptoService);
  final hiveKey = await appKeyService.ensureHiveKey();
  final keyBytes = base64Decode(hiveKey);
  final box = await Hive.openBox<AccountEntry>(
    AppConstants.accountBoxName,
    encryptionCipher: HiveAesCipher(keyBytes),
  );

  appAccountService = AccountService(box, appCryptoService, appKeyService);
  appTotpService = TotpService();
  appCsvService = CsvService(appAccountService, appKeyService, appCryptoService);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _wentBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 仅在真正进入后台（paused）时标记上锁，避免生物识别弹窗触发 inactive 导致误锁循环。
    if (state == AppLifecycleState.paused) {
      _wentBackground = true;
    }
    if (state == AppLifecycleState.resumed && _wentBackground) {
      _wentBackground = false;
      // 生物识别系统弹窗也会触发生命周期变化；若当前已在解锁页，不要重复跳转，避免打断认证流程。
      final currentPath = appRouter.routeInformationProvider.value.uri.path;
      if (currentPath != '/unlock') {
        appRouter.go('/unlock');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KeyKeeper',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      routerConfig: appRouter,
    );
  }
}