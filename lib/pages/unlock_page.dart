import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:key_keeper/common/constants.dart';
import 'package:local_auth/local_auth.dart';
import 'package:key_keeper/main.dart';

class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key, this.fromResumeLock = false});

  /// 为 true 时表示由后台恢复时在栈顶 [Navigator.push] 叠加，验证成功应 [pop] 回到原页面（如编辑中账户页）。
  final bool fromResumeLock;

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  bool _isBiometricAvailable = false;
  bool _isDeviceAuthAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  bool _authInProgress = false;
  bool _isMasterPasswordSet = false;
  String _unlockMethod = AppConstants.unlockMethodBiometric;
  bool _preferMasterPasswordEntry = false;
  bool _biometricAuthFailed = false;
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

  // 检查设备是否支持生物识别 / 系统凭据（PIN、图案、锁屏密码）
  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await localAuth.canCheckBiometrics;
      final isDeviceSupported = await localAuth.isDeviceSupported();
      final biometrics = await localAuth.getAvailableBiometrics();

      setState(() {
        _isBiometricAvailable = isAvailable && biometrics.isNotEmpty;
        _isDeviceAuthAvailable = isDeviceSupported;
        _availableBiometrics = biometrics;
      });
      final masterSet = await appKeyService.isAppMasterPasswordSet();
      final unlockMethod = await appKeyService.getUnlockMethod();
      if (!mounted) return;
      setState(() {
        _isMasterPasswordSet = masterSet;
        _unlockMethod = unlockMethod;
      });
      if (_unlockMethod == AppConstants.unlockMethodBiometric &&
          _isDeviceAuthAvailable) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
      }
    } catch (e) {
      debugPrint("检查生物识别失败：$e");
    }
  }

  // 执行生物识别/系统密码验证
  Future<void> _authenticate() async {
    if (_unlockMethod != AppConstants.unlockMethodBiometric ||
        !_isDeviceAuthAvailable) {
      return;
    }
    if (_authInProgress) return;
    setState(() => _authInProgress = true);
    bool authenticated = false;
    try {
      authenticated = await localAuth.authenticate(
        localizedReason: "验证身份以解锁 KeyKeeper",
        options: AuthenticationOptions(
          biometricOnly: false,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint(
        "验证失败（PlatformException）：code=${e.code}, message=${e.message}",
      );
    } catch (e) {
      debugPrint("验证失败：$e");
    } finally {
      if (mounted) setState(() => _authInProgress = false);
    }

    if (!mounted) return;
    if (authenticated) {
      _finishUnlock();
    } else {
      setState(() => _biometricAuthFailed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("验证失败，请重试")),
      );
    }
  }

  /// 设置里选了生物识别但本机不支持时，用主密码进入后把偏好改为主密码，避免下次仍走无效分支。
  Future<void> _syncUnlockMethodAfterFallbackSuccess() async {
    if (_unlockMethod == AppConstants.unlockMethodBiometric &&
        !_isDeviceAuthAvailable) {
      await appKeyService.setUnlockMethod(
        AppConstants.unlockMethodMasterPassword,
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
      await _syncUnlockMethodAfterFallbackSuccess();
      _isMasterPasswordSet = true;
      _confirmController.clear();
      if (!mounted) return;
      _showMessage('主密码设置成功');
      _finishUnlock();
      return;
    }

    final ok = await appKeyService.verifyAppMasterPassword(password);
    if (!mounted) return;
    if (ok) {
      await _syncUnlockMethodAfterFallbackSuccess();
      if (!mounted) return;
      _finishUnlock();
    } else {
      _showMessage('主密码错误，请重试');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// 从后台恢复时解锁页在栈顶，应 pop；冷启动仅 go_router 的 `/unlock` 时无上一页，需进入首页。
  Future<void> _finishUnlock() async {
    await appKeyService.warmUserKeyCache();
    await appAccountService.migrateLegacyEncryptionIfNeeded();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// 将系统返回的类型转为可读文案；Android 上常见 [BiometricType.weak] / [BiometricType.strong] 不单独展示括号，避免重复与术语噪音。
  static String _biometricTypeLabel(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return '面容识别';
      case BiometricType.fingerprint:
        return '指纹';
      case BiometricType.iris:
        return '虹膜';
      case BiometricType.weak:
      case BiometricType.strong:
        return '生物识别';
    }
  }

  /// 是否包含指纹/面容/虹膜等具体方式（仅 weak/strong 时不用于括号说明）。
  static bool _hasSpecificBiometricHardware(List<BiometricType> types) {
    return types.any(
      (t) =>
          t == BiometricType.face ||
          t == BiometricType.fingerprint ||
          t == BiometricType.iris,
    );
  }

  /// 去重后、用顿号连接，供副标题展示。
  static String _biometricTypesLine(List<BiometricType> types) {
    final seen = <String>{};
    final parts = <String>[];
    for (final t in types) {
      final label = _biometricTypeLabel(t);
      if (seen.add(label)) parts.add(label);
    }
    return parts.join('、');
  }

  /// 生物识别分支下「当前解锁方式」一行文案。
  String _biometricMethodLine() {
    if (!_isBiometricAvailable) {
      return "当前解锁方式：系统凭据（PIN / 图案 / 锁屏密码）";
    }
    if (_hasSpecificBiometricHardware(_availableBiometrics)) {
      return "当前解锁方式：生物识别（${_biometricTypesLine(_availableBiometrics)}）";
    }
    return "当前解锁方式：生物识别";
  }

  /// 已选生物识别但设备不支持时，在本页直接使用主密码，避免无法进入「我的」去切换。
  bool get _useMasterPasswordFallback =>
      _unlockMethod == AppConstants.unlockMethodBiometric &&
      !_isDeviceAuthAvailable;

  /// 当前中心区域是否应展示主密码输入。
  bool get _showMasterPasswordFields =>
      _unlockMethod == AppConstants.unlockMethodMasterPassword ||
      _useMasterPasswordFallback ||
      _preferMasterPasswordEntry;

  /// 是否处于「系统解锁模式」（非主密码输入态）。
  bool get _inBiometricMode =>
      _unlockMethod == AppConstants.unlockMethodBiometric &&
      _isDeviceAuthAvailable &&
      !_preferMasterPasswordEntry;

  @override
  Widget build(BuildContext context) {
    final bottomTextStyle = TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.primary,
      textStyle: const TextStyle(fontSize: 13),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );

    return PopScope(
      canPop: !widget.fromResumeLock,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.lock,
                            size: 52,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "KeyKeeper",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ── 系统解锁模式 ──
                        if (_inBiometricMode) ...[
                          Text(
                            _biometricMethodLine(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed:
                                _authInProgress ? null : _authenticate,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 15,
                              ),
                              textStyle: const TextStyle(fontSize: 18),
                            ),
                            child: Text(
                              _authInProgress ? "验证中..." : "解锁",
                            ),
                          ),
                        ],

                        // ── 主密码模式 ──
                        if (_showMasterPasswordFields) ...[
                          Text(
                            _useMasterPasswordFallback
                                ? "已选择生物识别，但本机不支持，请使用主密码解锁"
                                : "当前解锁方式：主密码",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: 320,
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscureMaster,
                              decoration: InputDecoration(
                                labelText: _isMasterPasswordSet
                                    ? '输入主密码'
                                    : '设置主密码',
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscureMaster = !_obscureMaster,
                                  ),
                                  icon: Icon(
                                    _obscureMaster
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
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
                                decoration: const InputDecoration(
                                  labelText: '确认主密码',
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _unlockWithMasterPassword,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 15,
                              ),
                              textStyle: const TextStyle(fontSize: 18),
                            ),
                            child: Text(
                              _isMasterPasswordSet ? '使用主密码解锁' : '设置并解锁',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── 底部蓝色小字：模式切换 ──
              // 系统解锁失败后 → 显示"改用主密码解锁"
              if (_inBiometricMode &&
                  _biometricAuthFailed &&
                  _isMasterPasswordSet)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        _passwordController.clear();
                        setState(() => _preferMasterPasswordEntry = true);
                      },
                      style: bottomTextStyle,
                      child: const Text('改用主密码解锁'),
                    ),
                  ),
                ),

              // 主密码模式 + 系统解锁可用 → 显示"返回系统解锁"
              if (_preferMasterPasswordEntry && _isDeviceAuthAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        _passwordController.clear();
                        setState(() => _preferMasterPasswordEntry = false);
                      },
                      style: bottomTextStyle,
                      child: const Text('返回系统解锁'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
