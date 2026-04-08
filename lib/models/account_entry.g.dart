// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_entry.dart';

class AccountEntryAdapter extends TypeAdapter<AccountEntry> {
  @override
  final int typeId = 1;

  @override
  AccountEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AccountEntry(
      typeText: fields[0] as String,
      username: fields[1] as String,
      passwordSecret: fields[2] as String?,
      totpSecret: fields[3] as String?,
      updateTime: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AccountEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.typeText)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.passwordSecret)
      ..writeByte(3)
      ..write(obj.totpSecret)
      ..writeByte(4)
      ..write(obj.updateTime);
  }
}
