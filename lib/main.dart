import 'dart:convert';
import 'dart:ui' show ImageFilter;

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

/// 与 [GoRouter] 共用，便于在应用从后台恢复时往**当前页面栈顶**叠加解锁页，保留 [Navigator.push] 打开的编辑页等。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
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
  appCsvService = CsvService(
    appAccountService,
    appKeyService,
    appCryptoService,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _wentBackground = false;

  /// 避免在解锁页未关闭时重复 [Navigator.push] 叠加多个解锁页。
  bool _resumeLockRoutePushed = false;

  /// 在进入任务切换/后台前尽早显示模糊遮罩，降低最近任务预览泄露内容的概率。
  bool _privacyShieldVisible = false;

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
    final shouldShowPrivacyShield = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    if (shouldShowPrivacyShield != _privacyShieldVisible) {
      setState(() => _privacyShieldVisible = shouldShowPrivacyShield);
    }

    // 仅在真正进入后台（paused）时标记上锁，避免生物识别弹窗触发 inactive 导致误锁循环。
    if (state == AppLifecycleState.paused) {
      _wentBackground = true;
    }
    if (state == AppLifecycleState.resumed && _wentBackground) {
      _wentBackground = false;
      // 生物识别系统弹窗也会触发生命周期变化；若当前已在 go_router 的解锁页，不要重复跳转。
      final currentPath = appRouter.routeInformationProvider.value.uri.path;
      if (currentPath == '/unlock') return;
      if (_resumeLockRoutePushed) return;
      final nav = rootNavigatorKey.currentState;
      if (nav == null) return;
      // 用叠加路由替代 go('/unlock')，避免清掉 Navigator.push 打开的新增/编辑页未保存状态。
      _resumeLockRoutePushed = true;
      nav
          .push<void>(
            MaterialPageRoute<void>(
              builder: (context) => const UnlockPage(fromResumeLock: true),
            ),
          )
          .whenComplete(() => _resumeLockRoutePushed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // [Stack] 在 [MaterialApp] 之上，须使用非方向性 alignment，否则会缺少 [Directionality] 祖先。
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      children: [
        MaterialApp.router(
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
        ),
        if (_privacyShieldVisible)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
