import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../data/api_client.dart';
import '../data/database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'upload_progress_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

final databaseProvider = Provider((ref) => AppDatabase());

final syncProvider = StateNotifierProvider<SyncNotifier, AsyncValue<List<LocalFile>>>((ref) {
  return SyncNotifier(
    ref.watch(apiClientProvider), 
    ref.watch(databaseProvider),
    ref,
  );
});

final isSyncingProvider = StateProvider<bool>((ref) => false);

class SyncNotifier extends StateNotifier<AsyncValue<List<LocalFile>>> {
  final ApiClient _api;
  final AppDatabase _db;
  final Ref _ref;

  SyncNotifier(this._api, this._db, this._ref) : super(const AsyncValue.loading()) {
    _loadFiles();
    Future.microtask(() => sync());
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
      final fileName = p.basename(file.path);
      final fileId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Start tracking progress
      _ref.read(uploadProgressProvider.notifier).startUpload(fileId, fileName);
      
      try {
        await _api.uploadFile(
          file, 
          'flutter-client',
          onProgress: (sent, total) {
            _ref.read(uploadProgressProvider.notifier).updateProgress(fileId, sent, total);
          },
        );
        
        // Mark as complete
        _ref.read(uploadProgressProvider.notifier).completeUpload(fileId);
        
        // Refresh file list
        await sync();
      } catch (e) {
        // Cancel progress on error
        _ref.read(uploadProgressProvider.notifier).cancelUpload(fileId);
        print("Upload failed: $e");
      }
    }
  }

  Future<void> sync() async {
    // Set syncing state to true
    _ref.read(isSyncingProvider.notifier).state = true;
    
    try {
      // 1. Get last sync time from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final lastSyncMillis = prefs.getInt('lastSyncTime') ?? 0;
      // Add a 10-second buffer to catch any files that might have been missed 
      // due to server processing time or clock skew.
      final since = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis)
          .subtract(const Duration(seconds: 10));
      
      print('Syncing changes since: $since');
      
      // 2. Fetch changes from server
      final response = await _api.getSyncChanges(since);
      
      // 3. Get server timestamp
      final serverTimestamp = response['serverTimestamp'] as String?;
      final syncTime = serverTimestamp != null 
          ? DateTime.parse(serverTimestamp)
          : DateTime.now();
      
      // 4. Process new files
      final changes = response['changes'] as Map<String, dynamic>?;
      if (changes != null) {
        final newFiles = changes['new'] as List<dynamic>? ?? [];
        
        print('Syncing ${newFiles.length} new files');
        
        // Save new files to local database
        for (final fileData in newFiles) {
          final fileMap = fileData as Map<String, dynamic>;
          
          await _db.into(_db.localFiles).insertOnConflictUpdate(
            LocalFilesCompanion.insert(
              id: fileMap['id'] as String,
              originalName: fileMap['originalName'] as String,
              size: fileMap['size'] as int,
              hash: fileMap['hash'] as String,
              uploadedAt: DateTime.parse(fileMap['uploadedAt'] as String),
              lastModified: DateTime.parse(fileMap['lastModified'] as String),
              version: Value(fileMap['version'] as int? ?? 1),
            ),
          );
        }
        
        // Handle deleted files
        final deletedFiles = changes['deleted'] as List<dynamic>? ?? [];
        
        print('Deleting ${deletedFiles.length} files from local DB');
        
        for (final fileData in deletedFiles) {
          final fileMap = fileData as Map<String, dynamic>;
          await (_db.delete(_db.localFiles)..where((t) => t.id.equals(fileMap['id'] as String))).go();
        }
      }
      
      // 5. Save sync timestamp
      await prefs.setInt('lastSyncTime', syncTime.millisecondsSinceEpoch);
      print('Saved last sync time: $syncTime');
      
      // 6. Reload local file list
      await _loadFiles();
      
    } catch (e) {
      print("Sync failed: $e");
      rethrow;
    } finally {
      // Always set syncing state back to false
      _ref.read(isSyncingProvider.notifier).state = false;
    }
  }

  Future<void> deleteFile(String fileId) async {
    try {
      // Delete from server
      await _api.deleteFile(fileId);
      
      // Delete from local database
      await (_db.delete(_db.localFiles)..where((t) => t.id.equals(fileId))).go();
      
      // Reload file list
      await _loadFiles();
    } catch (e) {
      print("Delete failed: $e");
      rethrow;
    }
  }

  Future<void> openFile(LocalFile file) async {
    try {
      // 0. Request Permissions
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        bool hasPermission = false;
        
        if (androidInfo.version.sdkInt >= 30) {
          var status = await Permission.manageExternalStorage.status;
          if (!status.isGranted) {
            status = await Permission.manageExternalStorage.request();
          }
          hasPermission = status.isGranted;
        } else {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          hasPermission = status.isGranted;
        }

        if (!hasPermission) {
          throw Exception("Permission denied. Enable 'Allow management of all files' in Settings.");
        }
      }

      // 1. Get Synce directory
      Directory? baseDir;
      if (Platform.isAndroid) {
        baseDir = await getExternalStorageDirectory();
        // Move up to the root of storage to find/create "Download" or similar public folder if needed
        // For now, getExternalStorageDirectory() returns /storage/emulated/0/Android/data/com.example.client/files
        // To save to public Downloads/Synce:
        baseDir = Directory('/storage/emulated/0/Download'); 
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
      
      final synceDir = Directory(p.join(baseDir!.path, 'Synce'));
      if (!await synceDir.exists()) {
        await synceDir.create(recursive: true);
      }

      final localPath = p.join(synceDir.path, file.originalName);
      print('Download destination path: $localPath');
      final localFile = File(localPath);

      bool needsDownload = true;

      // 2. Check if local file exists and hash matches
      if (await localFile.exists()) {
        final bytes = await localFile.readAsBytes();
        final localHash = sha256.convert(bytes).toString();
        if (localHash == file.hash) {
          needsDownload = false;
        } else {
          print('Hash mismatch for ${file.originalName}, re-downloading...');
        }
      }

      // 3. Download if needed
      if (needsDownload) {
        await _api.downloadFile(file.id, localPath);
        
        // Update local database with new path
        await (_db.update(_db.localFiles)
          ..where((t) => t.id.equals(file.id)))
          .write(LocalFilesCompanion(localPath: Value(localPath)));
      }

      // 4. Open file
      final result = await OpenFile.open(localPath);
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
    } catch (e) {
      print('Failed to open file: $e');
      rethrow;
    }
  }
}
