import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/integrations_tab.dart';
import '../widgets/memory_tab.dart';
import '../widgets/organization_tab.dart';
import '../widgets/profile_tab.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.tune), text: 'General'),
            Tab(icon: Icon(Icons.person_outline), text: 'Profile'),
            Tab(icon: Icon(Icons.business_outlined), text: 'Organization'),
            Tab(icon: Icon(Icons.psychology_outlined), text: 'Memory'),
            Tab(icon: Icon(Icons.cable_outlined), text: 'Integrations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _GeneralTab(),
          ProfileTab(),
          OrganizationTab(),
          MemoryTab(),
          IntegrationsTab(),
        ],
      ),
    );
  }
}

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (authState.user != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    child: Text(
                      authState.user!.name.isNotEmpty
                          ? authState.user!.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.user!.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          authState.user!.email,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Toggle dark theme'),
          value: settings.darkMode,
          onChanged: (_) =>
              ref.read(settingsProvider.notifier).toggleDarkMode(),
        ),
        const Divider(),
        ListTile(
          title: const Text('API Endpoint'),
          subtitle: Text(settings.apiEndpoint),
          trailing: const Icon(Icons.edit),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) {
                final controller =
                    TextEditingController(text: settings.apiEndpoint);
                return AlertDialog(
                  title: const Text('API Endpoint'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        ref
                            .read(settingsProvider.notifier)
                            .setApiEndpoint(controller.text);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            );
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('About'),
          subtitle: const Text('RAG Assistant v1.0.0'),
          leading: const Icon(Icons.info_outline),
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(authProvider.notifier).logout();
            context.go('/login');
          },
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text(
            'Logout',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
