import 'package:flutter/material.dart';

/// 全局常量：Secure Storage 键名、Hive Box 名、UI 预设等。
class AppConstants {
  // --- Secure Storage / Hive 键名 ---
  static const String accountBoxName = 'account_entry_box';
  /// Hive 整库 AES 加密密钥（32 字节 base64）。
  static const String hiveEncryptionKeyName = 'hive_encryption_key';
  /// 加密「个人密钥」用的随机种子。
  static const String initSecretName = 'init_secret';
  /// 经 initSecret 加密后的个人密钥。
  static const String userKeyEncryptedName = 'user_key_encrypted';
  static const String userKeySetName = 'user_key_set';
  /// 主密码 PBKDF2 哈希（或旧版 SHA256 十六进制）。
  static const String appMasterPasswordHashName = 'app_master_password_hash';
  static const String unlockMethodName = 'unlock_method';
  static const String unlockMethodBiometric = 'biometric';
  static const String unlockMethodMasterPassword = 'master_password';
  /// 从「快速选择类型」中移除的类型（小写），JSON 数组存于安全存储。
  static const String hiddenAccountTypeSuggestionsKey = 'hidden_account_type_suggestions';

  static const List<String> codeAccountType = <String>[
    'GitHub',
    'Microsoft',
    'Google',
    'Gitee',
  ];

  static const List<String> accountTypePresets = <String>[
    'GitHub',
    'Gitee',
    'Microsoft',
    'Google',
    'Weibo',
    'QQ',
    'WeiXin',
    'Huawei',
    'Bank',
    'BiliBili',
    'ZhiHu',
    'TaoBao',
    'JinDong',
  ];

  static const Map<String, IconData> iconMap = <String, IconData>{
    'github': Icons.code,
    'gitee': Icons.hub,
    'microsoft': Icons.window,
    'google': Icons.search,
    'weibo': Icons.rss_feed,
    'qq': Icons.chat_bubble,
    'weixin': Icons.wechat,
    'huawei': Icons.phone_android,
    'bank': Icons.account_balance,
    'bilibili': Icons.smart_display,
    'zhihu': Icons.help_outline,
    'taobao': Icons.shopping_bag,
    'jindong': Icons.shopping_cart,
  };
}
