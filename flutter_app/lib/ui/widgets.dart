import 'package:flutter/material.dart';

import '../engine/conjugation.dart';
import '../state/app_store.dart';
import 'furigana_text.dart';
import 'theme.dart';

/// Small orange tag chip (form tags in explanations).
class TagChip extends StatelessWidget {
  final String label;

  const TagChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.chip,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
}

/// Renders a word in kanji[kana] notation according to display mode
/// (kana-only, furigana, or plain kanji).
class WordText extends StatelessWidget {
  final String word;
  final bool kanaMode;
  final bool furigana;
  final TextStyle style;
  final Color? readingColor;

  const WordText(
    this.word, {
    super.key,
    required this.kanaMode,
    required this.furigana,
    required this.style,
    this.readingColor,
  });

  @override
  Widget build(BuildContext context) {
    if (kanaMode) {
      return Text(ConjugationEngine.kanaForm(word), style: style);
    }
    if (furigana) {
      return FuriganaText(word, style: style, readingColor: readingColor);
    }
    return Text(ConjugationEngine.kanjiForm(word), style: style);
  }
}

/// Section heading used across screens.
class SectionHeader extends StatelessWidget {
  final String text;

  const SectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: dark
              ? const Color(0xFF8FB4EA)
              : AppColors.indigo.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

/// Compact rounded checkbox tile (Anki-like quiet rows).
class CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const CheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.outlineDark : AppColors.outline;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? AppColors.indigo : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: value ? AppColors.indigo : border,
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 17, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          ],
        ),
      ),
    );
  }
}

/// Duolingo-style streak flame badge with count.
class StreakBadge extends StatelessWidget {
  final int streak;
  final double flameSize;

  const StreakBadge({super.key, required this.streak, this.flameSize = 22});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department,
            color: streak > 0 ? AppColors.flame : Colors.grey, size: flameSize),
        const SizedBox(width: 3),
        Text(
          '$streak',
          style: TextStyle(
            fontSize: flameSize * 0.8,
            fontWeight: FontWeight.w800,
            color: streak > 0 ? AppColors.flame : Colors.grey,
          ),
        ),
      ],
    );
  }
}

/// Circular daily-goal progress ring.
class GoalRing extends StatelessWidget {
  final int done;
  final int goal;

  const GoalRing({super.key, required this.done, required this.goal});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final track = dark ? AppColors.indigoSoftDark : AppColors.indigoSoft;
    final progress = goal <= 0 ? 0.0 : (done / goal).clamp(0.0, 1.0);
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 10,
            strokeCap: StrokeCap.round,
            backgroundColor: track,
            valueColor: const AlwaysStoppedAnimation(AppColors.indigo),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$done',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : AppColors.indigoDark,
                  ),
                ),
                Text(
                  '/ $goal',
                  style: TextStyle(
                    fontSize: 12,
                    color: (dark ? Colors.white : AppColors.indigoDark)
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Month calendar heatmap of practice history with month navigation,
/// replacing the weekly chart so all usage is trackable over time.
class MonthCalendar extends StatefulWidget {
  final StatsStore stats;
  final int goal;

  const MonthCalendar({super.key, required this.stats, required this.goal});

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _month = DateTime.now();

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S']; // Monday-first

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final outline = dark ? AppColors.outlineDark : AppColors.outline;
    final dimText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75);

    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Monday-first offset: DateTime.weekday is 1=Mon..7=Sun
    final leading = first.weekday - 1;
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _monthLabel(_month),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            _navButton(Icons.chevron_left, () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1, 1))),
            const SizedBox(width: 4),
            _navButton(Icons.chevron_right, () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1, 1))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: dimText),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              _dayCell(day, today, dark, dimText, outline),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('answered', style: TextStyle(fontSize: 11, color: dimText)),
            const SizedBox(width: 6),
            _swatch((dark ? AppColors.outlineDark : AppColors.outline).withValues(alpha: 0.45), dark),
            const SizedBox(width: 4),
            _swatch(AppColors.indigo.withValues(alpha: 0.55), dark),
            const SizedBox(width: 4),
            _swatch(AppColors.indigo, dark),
            const SizedBox(width: 6),
            Text('more  ·  tap a day for details',
                style: TextStyle(fontSize: 11, color: dimText)),
          ],
        ),
      ],
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon, size: 22),
      );

  Widget _swatch(Color color, bool dark) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: dark ? AppColors.outlineDark : AppColors.outline,
            width: 1,
          ),
        ),
      );

  Widget _dayCell(int day, DateTime today, bool dark, Color dimText, Color outline) {
    final date = DateTime(_month.year, _month.month, day);
    final key = _key(date);
    final answered = widget.stats.answeredOn(key);
    final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final goal = widget.goal;

    // Pure heatmap intensity: how much of the goal this day has covered.
    Color bg;
    double intensity = 0;
    if (answered > 0) {
      intensity =
          goal > 0 ? (answered / goal).clamp(0.0, 1.0) : 1.0;
    }
    if (answered == 0) {
      bg = outline.withValues(alpha: isFuture ? 0.22 : 0.35);
    } else {
      bg = AppColors.indigo.withValues(alpha: 0.35 + 0.65 * intensity);
    }

    return InkWell(
      onTap: isFuture
          ? null
          : () => _showDayDialog(context, date, answered),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isToday ? AppColors.indigo : outline.withValues(alpha: 0.6),
            width: isToday ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          answered == 0 ? '$day' : '$answered',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: answered == 0
                ? dimText
                : dark
                    ? AppColors.indigoDark
                    : Colors.white,
          ),
        ),
      ),
    );
  }

  void _showDayDialog(BuildContext context, DateTime date, int answered) {
    final correct = widget.stats.correctOn(_key(date));
    final goal = widget.goal;
    final names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${names[date.month]} ${date.day}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              answered == 0
                  ? 'No questions answered this day.'
                  : 'Correct answers: $correct\n'
                      'Daily goal: $goal\n'
                      'Goal covered: ${goal > 0 ? ((answered / goal) * 100).clamp(0, 100).round() : 100}%',
              style: const TextStyle(fontSize: 14.5, height: 1.5),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value:
                    goal <= 0 ? 1 : (answered / goal).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.12),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.indigo),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime m) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${names[m.month]} ${m.year}';
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
