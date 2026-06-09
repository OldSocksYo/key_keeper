import 'dart:convert';

/// 恒定时间比较字符串，用于密码/密钥比对，降低时序侧信道风险。
///
/// 普通 `==` 在发现第一个不同字节时即返回，攻击者可能通过耗时推断正确前缀。
bool secureCompareStrings(String a, String b) {
  final aBytes = utf8.encode(a);
  final bBytes = utf8.encode(b);
  if (aBytes.length != bBytes.length) return false;
  var diff = 0;
  for (var i = 0; i < aBytes.length; i++) {
    diff |= aBytes[i] ^ bBytes[i];
  }
  return diff == 0;
}

bool secureCompareBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
