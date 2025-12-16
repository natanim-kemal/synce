import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/api_client.dart';
import '../data/database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

final databaseProvider = Provider((ref) => AppDatabase());

final syncProvider = StateNotifierProvider<SyncNotifier, AsyncValue<List<LocalFile>>>((ref) {
  return SyncNotifier(ref.watch(apiClientProvider), ref.watch(databaseProvider));
});

class SyncNotifier extends StateNotifier<AsyncValue<List<LocalFile>>> {
  final ApiClient _api;
  final AppDatabase _db;

  SyncNotifier(this._api, this._db) : super(const AsyncValue.loading()) {
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final files = await _db.select(_db.localFiles).get();
      state = AsyncValue.data(files);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      try {
        await _api.uploadFile(file, 'android-emulator'); // hardcoded deviceId for now
        
        // Optimistic update or refresh
        // For now, let's just refresh list from sync
        await sync();
      } catch (e) {
        // Handle upload error
        print("Upload failed: $e");
      }
    }
  }

  Future<void> sync() async {
    try {
      // 1. Get last sync time (mocked for now, should store in prefs)
      final since = DateTime.fromMillisecondsSinceEpoch(0);
      
      // 2. Fetch changes
      final changes = await _api.getSyncChanges(since);
      
      // 3. Process changes (This is where the magic happens)
      // For now, just logging
      print("Sync changes: $changes");
      
      // Reload local DB view
      await _loadFiles();
      
    } catch (e) {
      print("Sync failed: $e");
    }
  }
}
