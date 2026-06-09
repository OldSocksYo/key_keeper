import 'package:otp/otp.dart';

/// TOTP 动态验证码生成（Google Authenticator 兼容：30 秒窗口、SHA1、6 位）。
class TotpService {
  /// 根据 Base32 密钥生成当前 6 位验证码。
  String generateCode(String base32Secret) {
    return OTP.generateTOTPCodeString(
      base32Secret,
      DateTime.now().millisecondsSinceEpoch,
      interval: 30,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
      length: 6,
    );
  }

  int getRemainingSeconds() {
    final sec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return 30 - (sec % 30);
  }

  bool isValidBase32(String input) {
    final value = input.trim().toUpperCase();
    if (value.isEmpty) return false;
    return RegExp(r'^[A-Z2-7]+=*$').hasMatch(value);
  }
}
