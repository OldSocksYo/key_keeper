import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:key_keeper/common/constants.dart';
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
  bool _isMasterPasswordSet = false;
  String _unlockMethod = AppConstants.unlockMethodBiometric;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscureMaster = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
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
      final masterSet = await appKeyService.isAppMasterPasswordSet();
      final unlockMethod = await appKeyService.getUnlockMethod();
      if (!mounted) return;
      setState(() {
        _isMasterPasswordSet = masterSet;
        _unlockMethod = unlockMethod;
      });
      if (_unlockMethod == AppConstants.unlockMethodBiometric && _isBiometricAvailable) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
      }
    } catch (e) {
      debugPrint("检查生物识别失败：$e");
    }
  }

  // 执行生物识别/系统密码验证
  Future<void> _authenticate() async {
    if (_unlockMethod != AppConstants.unlockMethodBiometric || !_isBiometricAvailable) return;
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

  Future<void> _unlockWithMasterPassword() async {
    final password = _passwordController.text;
    if (!_isMasterPasswordSet) {
      final confirm = _confirmController.text;
      if (password.trim().isEmpty) {
        _showMessage('请输入主密码');
        return;
      }
      if (password != confirm) {
        _showMessage('两次输入的密码不一致');
        return;
      }
      await appKeyService.setAppMasterPassword(password);
      _isMasterPasswordSet = true;
      _confirmController.clear();
      if (!mounted) return;
      _showMessage('主密码设置成功');
      context.go('/home');
      return;
    }

    final ok = await appKeyService.verifyAppMasterPassword(password);
    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      _showMessage('主密码错误，请重试');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
              _unlockMethod == AppConstants.unlockMethodBiometric
                  ? (_isBiometricAvailable
                      ? "当前解锁方式：生物识别（${_availableBiometrics.join(', ')}）"
                      : "已选择生物识别，但设备不支持，请在“我的-解锁方式”切换为主密码")
                  : "当前解锁方式：主密码",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (_unlockMethod == AppConstants.unlockMethodBiometric)
              ElevatedButton(
                onPressed: (!_isBiometricAvailable || _authInProgress) ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: Text(_authInProgress ? "验证中..." : "解锁"),
              ),
            if (_unlockMethod == AppConstants.unlockMethodMasterPassword) ...[
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscureMaster,
                  decoration: InputDecoration(
                    labelText: _isMasterPasswordSet ? '输入主密码' : '设置主密码',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureMaster = !_obscureMaster),
                      icon: Icon(_obscureMaster ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!_isMasterPasswordSet)
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _confirmController,
                    obscureText: _obscureMaster,
                    decoration: const InputDecoration(labelText: '确认主密码'),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _unlockWithMasterPassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: Text(_isMasterPasswordSet ? '使用主密码解锁' : '设置并解锁'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}