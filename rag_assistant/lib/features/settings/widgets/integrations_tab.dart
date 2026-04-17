import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectors_provider.dart';

class IntegrationsTab extends ConsumerStatefulWidget {
  const IntegrationsTab({super.key});

  @override
  ConsumerState<IntegrationsTab> createState() => _IntegrationsTabState();
}

class _IntegrationsTabState extends ConsumerState<IntegrationsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(connectorsProvider.notifier).loadStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectorsProvider);
    final primary = Theme.of(context).colorScheme.primary;

    if (state.isLoading && state.connections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Connect external services to give your AI coworker richer context.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),

          // Google Calendar card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.calendar_month, color: primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Google Calendar',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              state.isGoogleConnected
                                  ? 'Connected'
                                  : 'Not connected',
                              style: TextStyle(
                                fontSize: 12,
                                color: state.isGoogleConnected
                                    ? Colors.green
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.isGoogleConnected)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),

                  if (state.isGoogleConnected) ...[
                    const SizedBox(height: 16),
                    _infoRow('Account', state.googleConnection?.accountEmail ?? 'Unknown'),
                    _infoRow('Last synced', state.googleConnection?.lastSyncedAt ?? 'Never'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: state.isSyncing
                                ? null
                                : () => ref.read(connectorsProvider.notifier).sync(),
                            icon: state.isSyncing
                                ? const SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync, size: 18),
                            label: const Text('Sync Now'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Disconnect?'),
                                  content: const Text('Your calendar events will be removed.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('Disconnect'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                ref.read(connectorsProvider.notifier).disconnect();
                              }
                            },
                            icon: const Icon(Icons.link_off, size: 18, color: Colors.red),
                            label: const Text('Disconnect', style: TextStyle(color: Colors.red)),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Text(
                      state.googleConfigured
                          ? 'Click below to connect your Google Calendar. Your meetings will appear in daily briefs and be available as chat context.'
                          : 'Google OAuth is not configured yet. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in your backend .env file.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: state.googleConfigured
                          ? () async {
                              final url = await ref.read(connectorsProvider.notifier).getAuthorizeUrl();
                              if (url != null && context.mounted) {
                                await Clipboard.setData(ClipboardData(text: url));
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Auth URL copied — open it in your browser to connect')),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Connect Google Calendar'),
                    ),
                  ],

                  // Dev-seed button (always visible for testing)
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.science_outlined, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dev testing: seed fake calendar events (no GCP setup needed)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ),
                      TextButton(
                        onPressed: state.isSeeding
                            ? null
                            : () async {
                                await ref.read(connectorsProvider.notifier).devSeed();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Fake events seeded')),
                                );
                              },
                        child: state.isSeeding
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Seed Events'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          if (state.successMessage != null) ...[
            const SizedBox(height: 12),
            Text(state.successMessage!, style: const TextStyle(color: Colors.green, fontSize: 12)),
          ],

          const SizedBox(height: 32),
          Text(
            'More integrations coming soon: Gmail, Slack, meeting transcripts.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
