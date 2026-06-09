import 'dart:async';

import 'package:flutter/foundation.dart';

/// 全局 TOTP 倒计时广播，避免列表中每行各自创建 Timer。
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
