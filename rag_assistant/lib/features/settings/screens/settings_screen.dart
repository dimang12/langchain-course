import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle dark theme'),
            value: settings.darkMode,
            onChanged: (_) {
              ref.read(settingsProvider.notifier).toggleDarkMode();
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('API Endpoint'),
            subtitle: Text(settings.apiEndpoint),
            trailing: const Icon(Icons.edit),
            onTap: () {
              // TODO: Show endpoint edit dialog
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('About'),
            subtitle: const Text('RAG Assistant v1.0.0'),
            leading: const Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }
}
