import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'logic/sync_provider.dart';
import 'logic/auth_provider.dart';
import 'data/api_client.dart';
import 'data/database.dart';
import 'widgets/upload_progress_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesState = ref.watch(syncProvider);
    final isSyncing = ref.watch(isSyncingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synce'),
        actions: [
          IconButton(
            icon: isSyncing 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
            onPressed: isSyncing ? null : () async {
              try {
                await ref.read(syncProvider.notifier).sync();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Synced successfully'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.white,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sync failed: $e'),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettingsDialog(context);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncProvider.notifier).sync(),
        child: Column(
          children: [
            const UploadProgressList(),
            Expanded(
              child: filesState.when(
                data: (files) {
                  if (files.isEmpty) {
                    return _EmptyState(ref: ref);
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmallScreen = constraints.maxWidth < 600;
                      final isMediumScreen = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
                      
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: DataTable(
                            columnSpacing: isSmallScreen ? 16 : 24,
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Last Modified')),
                              DataColumn(label: Text('Size')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: files.map((file) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: isSmallScreen 
                                        ? constraints.maxWidth * 0.3
                                        : isMediumScreen 
                                          ? constraints.maxWidth * 0.4
                                          : constraints.maxWidth * 0.5,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.picture_as_pdf, size: 20, color: Colors.red),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              file.originalName,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    onTap: () async {
                                      try {
                                        await ref.read(syncProvider.notifier).openFile(file);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Could not open file: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  DataCell(Text(_formatDate(file.lastModified))),
                                  DataCell(Text(_formatFileSize(file.size))),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20),
                                      color: Colors.red,
                                      onPressed: () async {
                                        // Show confirmation dialog
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete File?'),
                                            content: Text('Delete "${file.originalName}"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        
                                        if (confirmed == true) {
                                          try {
                                            await ref.read(syncProvider.notifier).deleteFile(file.id);
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Delete failed: $e')),
                                              );
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  );
                },
                error: (err, stack) => Text('Error: $err'),
                loading: () => const CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(syncProvider.notifier).pickAndUploadFile(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          return AlertDialog(
            title: const Text('Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Account'),
                  subtitle: FutureBuilder<String?>(
                    future: ref.read(apiClientProvider).getToken(), 
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return const Text('Logged in');
                      }
                      return const Text('Not logged in');
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  subtitle: const Text('1.0.0'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final authNotifier = ref.read(authProvider.notifier);
                  Navigator.pop(context);
                  await authNotifier.logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          );
        },
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
    return Center(
      child: Column(
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
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final fileDate = DateTime(date.year, date.month, date.day);
  
  if (fileDate == today) {
    return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  } else {
    return '${date.month}/${date.day}/${date.year}';
  }
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
