import 'package:flutter/material.dart';

import '../state/app_store.dart';
import 'theme.dart';

/// Session-complete screen. With the re-queue rule every question is mastered
/// before a session ends, so there is no right/wrong tally — just the work
/// done and the streak it fed.
class CompleteScreen extends StatelessWidget {
  final int mastered;
  final int attempts;
  final AppStore store;

  const CompleteScreen({
    super.key,
    required this.mastered,
    required this.attempts,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final streak = store.stats.currentStreak;
    final extraAttempts = attempts - mastered;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: AppColors.gold,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Session complete!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.indigoDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All $mastered questions mastered.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _statTile(
                      context,
                      '$mastered',
                      'mastered',
                      AppColors.success,
                    ),
                    const SizedBox(width: 12),
                    _statTile(
                      context,
                      '$attempts',
                      'attempts',
                      AppColors.indigo,
                    ),
                    const SizedBox(width: 12),
                    _statTile(
                      context,
                      '$streak',
                      'day streak',
                      AppColors.flame,
                    ),
                  ],
                ),
                if (extraAttempts > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    '$extraAttempts extra ${extraAttempts == 1 ? "try" : "tries"} on the tricky ones — that\'s how it sticks.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.75),
                    ),
                  ),
                ],
                const Spacer(),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Finish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statTile(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
