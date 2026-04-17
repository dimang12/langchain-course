import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/memory_models.dart';
import '../providers/memory_provider.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _role = TextEditingController();
  final _team = TextEditingController();
  final _responsibilities = TextEditingController();
  final _workingHours = TextEditingController();
  final _timezone = TextEditingController();
  final _communicationStyle = TextEditingController();

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memoryProvider.notifier).loadProfile();
    });
  }

  void _hydrate(UserProfileModel profile) {
    _role.text = profile.role ?? '';
    _team.text = profile.team ?? '';
    _responsibilities.text = profile.responsibilities ?? '';
    _workingHours.text = profile.workingHours ?? '';
    _timezone.text = profile.timezone ?? '';
    _communicationStyle.text = profile.communicationStyle ?? '';
    _loaded = true;
  }

  @override
  void dispose() {
    _role.dispose();
    _team.dispose();
    _responsibilities.dispose();
    _workingHours.dispose();
    _timezone.dispose();
    _communicationStyle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final updated = UserProfileModel(
      role: _role.text.trim().isEmpty ? null : _role.text.trim(),
      team: _team.text.trim().isEmpty ? null : _team.text.trim(),
      responsibilities: _responsibilities.text.trim().isEmpty
          ? null
          : _responsibilities.text.trim(),
      workingHours: _workingHours.text.trim().isEmpty
          ? null
          : _workingHours.text.trim(),
      timezone: _timezone.text.trim().isEmpty ? null : _timezone.text.trim(),
      communicationStyle: _communicationStyle.text.trim().isEmpty
          ? null
          : _communicationStyle.text.trim(),
    );

    final ok = await ref.read(memoryProvider.notifier).saveProfile(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Profile saved' : 'Save failed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryProvider);

    if (state.isLoadingProfile && !_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_loaded) {
      _hydrate(state.profile);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tell your AI coworker who you are. This context is injected into every conversation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _field(
              controller: _role,
              label: 'Role',
              hint: 'e.g., Solo developer, Product Manager',
            ),
            _field(
              controller: _team,
              label: 'Team',
              hint: 'e.g., Platform, Growth, Engineering',
            ),
            _field(
              controller: _responsibilities,
              label: 'Responsibilities',
              hint: 'What you do day-to-day',
              maxLines: 3,
            ),
            _field(
              controller: _workingHours,
              label: 'Working hours',
              hint: 'e.g., 09:00-18:00',
            ),
            _field(
              controller: _timezone,
              label: 'Timezone',
              hint: 'e.g., America/Los_Angeles',
            ),
            _field(
              controller: _communicationStyle,
              label: 'Communication style',
              hint: 'e.g., terse, detailed, formal, casual',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: state.isSavingProfile ? null : _save,
              icon: state.isSavingProfile
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Profile'),
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
