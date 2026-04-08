import 'package:hive/hive.dart';

part 'user_account.g.dart';

@HiveType(typeId: 0)
class UserAccount extends HiveObject {
  UserAccount({
    required this.typeText,
    required this.username,
    required this.secret,
    required this.type,
    required this.updateTime,
  });

  @HiveField(0)
  String typeText;

  @HiveField(1)
  String username;

  @HiveField(2)
  String secret;

  @HiveField(3)
  int type; // 0 normal, 1 totp

  @HiveField(4)
  int updateTime;
}
