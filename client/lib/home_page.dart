import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'logic/sync_provider.dart';
import 'data/database.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesState = ref.watch(syncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synce'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              ref.read(syncProvider.notifier).sync();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Open settings
            },
          ),
        ],
      ),
      body: Center(
        child: filesState.when(
          data: (files) {
            if (files.isEmpty) {
              return _EmptyState(ref: ref);
            }
            return ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(file.originalName),
                  subtitle: Text('${file.size} bytes'),
                );
              },
            );
          },
          error: (err, stack) => Text('Error: $err'),
          loading: () => const CircularProgressIndicator(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(syncProvider.notifier).pickAndUploadFile(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.ref,
  });

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.library_books_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
         const SizedBox(height: 16),
        Text(
          'No PDF files yet',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
         const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
             ref.read(syncProvider.notifier).pickAndUploadFile();
          },
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload PDF'),
        ),
      ],
    );
  }
}
