import 'package:otp/otp.dart';

class TotpService {
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
