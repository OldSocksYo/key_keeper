import 'package:flutter/material.dart';

class AppConstants {
  static const String accountBoxName = 'account_entry_box';
  static const String hiveEncryptionKeyName = 'hive_encryption_key';
  static const String initSecretName = 'init_secret';
  static const String userKeyEncryptedName = 'user_key_encrypted';
  static const String userKeySetName = 'user_key_set';

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
