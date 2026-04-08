import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:key_keeper/main.dart';

class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key});

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  bool _isBiometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  // 检查设备是否支持生物识别
  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await localAuth.canCheckBiometrics;
      final isDeviceSupported = await localAuth.isDeviceSupported();
      final biometrics = await localAuth.getAvailableBiometrics();

      setState(() {
        _isBiometricAvailable = isAvailable && isDeviceSupported;
        _availableBiometrics = biometrics;
      });
    } catch (e) {
      debugPrint("检查生物识别失败：$e");
    }
  }

  // 执行生物识别/系统密码验证
  Future<void> _authenticate() async {
    if (_authInProgress) return;
    _authInProgress = true;
    bool authenticated = false;
    try {
      authenticated = await localAuth.authenticate(
        localizedReason: "验证身份以解锁 KeyKeeper",
        options: AuthenticationOptions(
          biometricOnly: false, // 失败时显示系统密码
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint("验证失败：$e");
    } finally {
      _authInProgress = false;
    }

    if (!mounted) return;
    if (authenticated) {
      // 验证成功：跳转到首页
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("验证失败，请重试")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.lock,
                size: 52,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "KeyKeeper",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            Text(
              _isBiometricAvailable
                  ? "支持的解锁方式：${_availableBiometrics.join(', ')}"
                  : "设备不支持生物识别",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _authInProgress ? null : _authenticate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: Text(_authInProgress ? "验证中..." : "解锁"),
            ),
          ],
        ),
      ),
    );
  }
}