import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/password_model.dart';
import 'local_db_service.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  final _supabase = Supabase.instance.client;
  final _localDb = LocalDatabaseService();

  /// Pull data from Supabase and sync to local Isar
  Future<void> pullFromSupabase() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase.from('passwords').select().order('app_name');
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

      final List<Password> remotePasswords = data.map((m) => Password.fromMap(m)).toList();

      for (var rp in remotePasswords) {
        if (rp.supabaseId == null) continue;
        
        final existing = await _localDb.getBySupabaseId(rp.supabaseId!);
        if (existing != null) {
          rp.localId = existing.localId;
        }
        await _localDb.savePassword(rp);
      }
      debugPrint("SyncService: Pull completed. Synced ${remotePasswords.length} items.");
    } catch (e) {
      debugPrint("SyncService: Pull Error: $e");
    }
  }

  /// Push local change to Supabase
  Future<bool> pushToSupabase(Password p) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final data = p.toMap();
      data['user_id'] = user.id;

      if (p.supabaseId == null) {
        // Insert new
        final response = await _supabase.from('passwords').insert(data).select().single();
        p.supabaseId = response['id'].toString();
        p.isSynced = true;
        await _localDb.savePassword(p);
      } else {
        // Update existing
        await _supabase.from('passwords').update(data).eq('id', p.supabaseId!);
        p.isSynced = true;
        await _localDb.savePassword(p);
      }
      return true;
    } catch (e) {
      debugPrint("SyncService: Push Error: $e");
      // Mark as unsynced for later retry
      p.isSynced = false;
      await _localDb.savePassword(p);
      return false;
    }
  }

  /// Handle deletion
  Future<bool> deleteFromSupabase(String supabaseId) async {
    try {
      await _supabase.from('passwords').delete().eq('id', supabaseId);
      return true;
    } catch (e) {
      debugPrint("SyncService: Delete Error: $e");
      return false;
    }
  }
}
