// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAccountAdapter extends TypeAdapter<UserAccount> {
  @override
  final int typeId = 0;

  @override
  UserAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserAccount(
      typeText: fields[0] as String,
      username: fields[1] as String,
      secret: fields[2] as String,
      type: fields[3] as int,
      updateTime: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, UserAccount obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.typeText)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.secret)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.updateTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
