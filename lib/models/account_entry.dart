import 'package:hive/hive.dart';

part 'account_entry.g.dart';

/// 账号实体，持久化到 Hive。
///
/// 注意：[passwordSecret] 与 [totpSecret] 在库中存的是**密文**；
/// 读取时需经 [AccountService] 用个人密钥解密后才为明文。
@HiveType(typeId: 1)
class AccountEntry extends HiveObject {
  AccountEntry({
    required this.typeText,
    required this.username,
    required this.passwordSecret,
    required this.totpSecret,
    required this.updateTime,
  });

  @HiveField(0)
  String typeText;

  @HiveField(1)
  String username;

  /// 加密后的登录密码；列表模式下可能为 null（未解密）。
  @HiveField(2)
  String? passwordSecret;

  /// 加密后的 TOTP 密钥（Base32 明文经加密后存储）。
  @HiveField(3)
  String? totpSecret;

  /// 最后更新时间（Unix 秒），用于列表排序。
  @HiveField(4)
  int updateTime;

  /// 密文字段非空即视为有密码（无需解密即可判断）。
  bool get hasPassword => (passwordSecret ?? '').trim().isNotEmpty;
  bool get hasTotp => (totpSecret ?? '').trim().isNotEmpty;
}
