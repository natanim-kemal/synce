import 'package:flutter_riverpod/flutter_riverpod.dart';

class UploadProgress {
  final String fileName;
  final int sent;
  final int total;
  final bool isComplete;

  UploadProgress({
    required this.fileName,
    required this.sent,
    required this.total,
    this.isComplete = false,
  });

  double get progress => total > 0 ? sent / total : 0.0;
  int get percentage => (progress * 100).toInt();

  UploadProgress copyWith({
    String? fileName,
    int? sent,
    int? total,
    bool? isComplete,
  }) {
    return UploadProgress(
      fileName: fileName ?? this.fileName,
      sent: sent ?? this.sent,
      total: total ?? this.total,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

final uploadProgressProvider = StateNotifierProvider<UploadProgressNotifier, Map<String, UploadProgress>>((ref) {
  return UploadProgressNotifier();
});

class UploadProgressNotifier extends StateNotifier<Map<String, UploadProgress>> {
  UploadProgressNotifier() : super({});

  void updateProgress(String fileId, int sent, int total) {
    state = {
      ...state,
      fileId: UploadProgress(
        fileName: state[fileId]?.fileName ?? 'Unknown',
        sent: sent,
        total: total,
      ),
    };
  }

  void startUpload(String fileId, String fileName) {
    state = {
      ...state,
      fileId: UploadProgress(fileName: fileName, sent: 0, total: 0),
    };
  }

  void completeUpload(String fileId) {
    final current = state[fileId];
    if (current != null) {
      state = {
        ...state,
        fileId: current.copyWith(isComplete: true),
      };
      
      // Remove after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        final newState = Map<String, UploadProgress>.from(state);
        newState.remove(fileId);
        state = newState;
      });
    }
  }

  void cancelUpload(String fileId) {
    final newState = Map<String, UploadProgress>.from(state);
    newState.remove(fileId);
    state = newState;
  }
}
