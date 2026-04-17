import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sources_provider.dart';

class SourcesScreen extends ConsumerStatefulWidget {
  const SourcesScreen({super.key});

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(sourcesProvider.notifier).loadSources());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'complete':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourcesState = ref.watch(sourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sources'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(sourcesProvider.notifier).loadSources(),
          ),
        ],
      ),
      body: sourcesState.isLoading && sourcesState.sources.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : sourcesState.sources.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_file, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text('No documents uploaded yet'),
                      const SizedBox(height: 8),
                      const Text('Tap + to upload your first document'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(sourcesProvider.notifier).loadSources(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sourcesState.sources.length,
                    itemBuilder: (context, index) {
                      final source = sourcesState.sources[index];
                      return Dismissible(
                        key: Key(source.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => ref.read(sourcesProvider.notifier).deleteSource(source.id),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.description),
                            title: Text(source.filename),
                            subtitle: source.chunks != null
                                ? Text('${source.chunks} chunks')
                                : source.error != null
                                    ? Text(source.error!, style: const TextStyle(color: Colors.red))
                                    : null,
                            trailing: Chip(
                              label: Text(source.status, style: const TextStyle(fontSize: 12, color: Colors.white)),
                              backgroundColor: _statusColor(source.status),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: sourcesState.isLoading ? null : () => ref.read(sourcesProvider.notifier).uploadFile(),
        icon: const Icon(Icons.upload),
        label: const Text('Upload'),
      ),
    );
  }
}
