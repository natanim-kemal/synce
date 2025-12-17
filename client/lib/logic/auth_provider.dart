import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/api_client.dart';
import 'sync_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<bool>>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref _ref;
  final ApiClient _api;

  AuthNotifier(this._ref) : _api = _ref.read(apiClientProvider), super(const AsyncValue.loading()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    try {
      final token = await _api.getToken();
      state = AsyncValue.data(token != null);
    } catch (e, st) {
       state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _api.login(email, password);
      state = const AsyncValue.data(true);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _api.register(email, password);
      state = const AsyncValue.data(true);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    
    // Clear local database
    final db = _ref.read(databaseProvider);
    await db.delete(db.localFiles).go();
    
    // Clear last sync time
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastSyncTime');
    
    // Invalidate providers to clear memory state
    _ref.invalidate(syncProvider);
    _ref.invalidate(isSyncingProvider);
    
    state = const AsyncValue.data(false);
  }
}
