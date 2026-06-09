import 'dart:async';

import 'package:flutter/foundation.dart';

/// 全局 TOTP 倒计时广播（单例）。
///
/// 列表中每个含 TOTP 的条目只需监听此对象，而非各自 [Timer.periodic]，
/// 避免 N 个账号产生 N 个定时器。
class TotpTicker extends ChangeNotifier {
  TotpTicker._();

  static final TotpTicker instance = TotpTicker._();

  Timer? _timer;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _ensureStarted();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _ensureStarted() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }
}
