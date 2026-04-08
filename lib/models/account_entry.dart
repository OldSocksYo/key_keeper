import 'package:hive/hive.dart';

part 'account_entry.g.dart';

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

  @HiveField(2)
  String? passwordSecret;

  @HiveField(3)
  String? totpSecret;

  @HiveField(4)
  int updateTime;

  bool get hasPassword => (passwordSecret ?? '').trim().isNotEmpty;
  bool get hasTotp => (totpSecret ?? '').trim().isNotEmpty;
}
