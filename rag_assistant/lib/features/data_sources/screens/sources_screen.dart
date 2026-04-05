import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sources_provider.dart';

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesState = ref.watch(sourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sources'),
      ),
      body: sourcesState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : sourcesState.sources.isEmpty
              ? const Center(
                  child: Text('No data sources added yet'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sourcesState.sources.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(sourcesState.sources[index]),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement file picker
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
