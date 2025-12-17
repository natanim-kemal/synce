import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/upload_progress_provider.dart';

class UploadProgressCard extends ConsumerWidget {
  final String fileId;

  const UploadProgressCard({super.key, required this.fileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(uploadProgressProvider);
    final progress = uploadState[fileId];

    if (progress == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children:[ Text(
              progress.fileName,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress.progress,
                    backgroundColor: Colors.grey[300],
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  progress.isComplete ? '✓' : '${progress.percentage}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: progress.isComplete ? Colors.green : null,
                  ),
                ),
              ],
            ),
            if (!progress.isComplete) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    ref.read(uploadProgressProvider.notifier).cancelUpload(fileId);
                  },
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class UploadProgressList extends ConsumerWidget {
  const UploadProgressList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploads = ref.watch(uploadProgressProvider);

    if (uploads.isEmpty) return const SizedBox.shrink();

    return Column(
      children: uploads.keys.map((fileId) => UploadProgressCard(fileId: fileId)).toList(),
    );
  }
}
