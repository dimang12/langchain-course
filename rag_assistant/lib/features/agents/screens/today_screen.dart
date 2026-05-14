import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/agent_run_model.dart';
import '../providers/agents_provider.dart';
import '../widgets/activity_feed.dart';
import '../widgets/brief_card.dart';
import '../widgets/prioritizer_card.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(agentsProvider.notifier).loadRuns();
    });
  }

  Future<void> _trigger() async {
    final run = await ref.read(agentsProvider.notifier).triggerPrioritizer();
    if (!mounted) return;
    if (run != null && run.status == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Priorities ready')),
      );
    } else if (run?.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prioritizer failed: ${run!.errorMessage}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentsProvider);
    final prioritizer = state.latestPrioritizer;
    final legacy = state.latestDailyBrief;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final mainColumn = _mainColumn(prioritizer, legacy, state.isTriggering);
        final feedColumn = _feedColumn();

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: mainColumn,
                ),
              ),
              Container(
                width: 320,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text(
                        'ACTIVITY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Expanded(child: feedColumn),
                  ],
                ),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              mainColumn,
              const SizedBox(height: 24),
              Text(
                'ACTIVITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 400,
                child: feedColumn,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mainColumn(AgentRunModel? prioritizer, AgentRunModel? legacy, bool isTriggering) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    _formattedDate(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: isTriggering ? null : _trigger,
              style: FilledButton.styleFrom(
                minimumSize: const Size(180, 44),
              ),
              icon: isTriggering
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                isTriggering ? 'Thinking…' : 'Prioritize',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (prioritizer != null) PrioritizerCard(run: prioritizer),
        if (prioritizer != null && legacy != null) const SizedBox(height: 16),
        if (legacy != null) BriefCard(run: legacy),
        if (prioritizer == null && legacy == null) _emptyBrief(),
      ],
    );
  }

  Widget _feedColumn() {
    return const ActivityFeed();
  }

  Widget _emptyBrief() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No brief yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Your AI coworker generates a personalized brief every morning at 8am. '
            'You can also generate one on demand using the button above.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tip: fill in your Profile and Organization in Settings first — '
            'the brief only gets good when it knows who you are.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _formattedDate() {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}
