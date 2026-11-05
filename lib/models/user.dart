import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 2)
class User extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String email;

  @HiveField(2)
  String password; // In production, use hashed password!

  @HiveField(3)
  String name;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime? lastLogin;

  User({
    required this.id,
    required this.email,
    required this.password,
    required this.name,
    required this.createdAt,
    this.lastLogin,
  });
}
