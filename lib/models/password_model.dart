import 'package:isar/isar.dart';

part 'password_model.g.dart';

@collection
class Password {
  Id localId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String? supabaseId;

  late String appName;
  late String appUsername;
  late String encryptedPassword;
  late String iv;
  bool isFavorite = false;
  DateTime? createdAt;

  // Metadata for sync
  bool isSynced = true;
  bool isDeleted = false; // Mark for background deletion if offline

  /// Convert from Supabase Map
  static Password fromMap(Map<String, dynamic> map) {
    return Password()
      ..supabaseId = map['id']?.toString()
      ..appName = map['app_name'] ?? ''
      ..appUsername = map['app_username'] ?? ''
      ..encryptedPassword = map['encrypted_password'] ?? ''
      ..iv = map['iv'] ?? ''
      ..isFavorite = map['is_favorite'] ?? false
      ..createdAt = map['created_at'] != null ? DateTime.parse(map['created_at']) : null
      ..isSynced = true;
  }

  /// Convert to Supabase Map
  Map<String, dynamic> toMap() {
    return {
      'app_name': appName,
      'app_username': appUsername,
      'encrypted_password': encryptedPassword,
      'iv': iv,
      'is_favorite': isFavorite,
      // 'id' and 'created_at' usually handled by Supabase on insert
    };
  }
}
