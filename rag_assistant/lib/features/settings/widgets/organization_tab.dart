import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/memory_models.dart';
import '../providers/memory_provider.dart';

class OrganizationTab extends ConsumerStatefulWidget {
  const OrganizationTab({super.key});

  @override
  ConsumerState<OrganizationTab> createState() => _OrganizationTabState();
}

class _OrganizationTabState extends ConsumerState<OrganizationTab> {
  final _formKey = GlobalKey<FormState>();
  final _orgName = TextEditingController();
  final _mission = TextEditingController();
  final _currentQuarter = TextEditingController();
  final _quarterGoals = TextEditingController();
  final _leadershipPriorities = TextEditingController();
  final _teamOkrs = TextEditingController();

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memoryProvider.notifier).loadOrg();
    });
  }

  void _hydrate(OrgContextModel org) {
    _orgName.text = org.orgName ?? '';
    _mission.text = org.mission ?? '';
    _currentQuarter.text = org.currentQuarter ?? '';
    _quarterGoals.text = org.quarterGoals ?? '';
    _leadershipPriorities.text = org.leadershipPriorities ?? '';
    _teamOkrs.text = org.teamOkrs ?? '';
    _loaded = true;
  }

  @override
  void dispose() {
    _orgName.dispose();
    _mission.dispose();
    _currentQuarter.dispose();
    _quarterGoals.dispose();
    _leadershipPriorities.dispose();
    _teamOkrs.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    String? trim(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final updated = OrgContextModel(
      orgName: trim(_orgName),
      mission: trim(_mission),
      currentQuarter: trim(_currentQuarter),
      quarterGoals: trim(_quarterGoals),
      leadershipPriorities: trim(_leadershipPriorities),
      teamOkrs: trim(_teamOkrs),
    );

    final ok = await ref.read(memoryProvider.notifier).saveOrg(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Organization saved' : 'Save failed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryProvider);

    if (state.isLoadingOrg && !_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_loaded) {
      _hydrate(state.org);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your AI coworker uses organizational context to align with what matters most this quarter.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _field(
              controller: _orgName,
              label: 'Organization name',
              hint: 'e.g., Acme Corp, Personal',
            ),
            _field(
              controller: _mission,
              label: 'Mission',
              hint: 'What the organization exists to do',
              maxLines: 3,
            ),
            _field(
              controller: _currentQuarter,
              label: 'Current quarter',
              hint: 'e.g., Q2 2026',
            ),
            _field(
              controller: _quarterGoals,
              label: 'Quarter goals',
              hint: 'Top objectives for this quarter',
              maxLines: 5,
            ),
            _field(
              controller: _leadershipPriorities,
              label: 'Leadership priorities',
              hint: 'What leadership is emphasizing',
              maxLines: 5,
            ),
            _field(
              controller: _teamOkrs,
              label: 'Team OKRs',
              hint: 'Your team\'s key results',
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: state.isSavingOrg ? null : _save,
              icon: state.isSavingOrg
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Organization'),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(
                state.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }
}
