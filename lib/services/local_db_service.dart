import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/password_model.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Isar? _isar;

  Future<void> init() async {
    if (_isar != null) return;
    
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [PasswordSchema],
      directory: dir.path,
      inspector: false, // Tắt để tránh treo app khi khởi động
    );
  }

  Isar get isar => _isar!;

  // Passwords CRUD
  Future<void> savePassword(Password p) async {
    await isar.writeTxn(() async {
      await isar.passwords.put(p);
    });
  }

  Future<void> saveAllPasswords(List<Password> list) async {
    await isar.writeTxn(() async {
      await isar.passwords.putAll(list);
    });
  }

  Future<List<Password>> getAllPasswords() async {
    return await isar.passwords.where().sortByAppName().findAll();
  }

  Future<void> deleteByLocalId(int localId) async {
    await isar.writeTxn(() async {
      await isar.passwords.delete(localId);
    });
  }

  Future<Password?> getBySupabaseId(String id) async {
    return await isar.passwords.filter().supabaseIdEqualTo(id).findFirst();
  }

  Future<void> clearAll() async {
    await isar.writeTxn(() async {
      await isar.passwords.clear();
    });
  }
}
