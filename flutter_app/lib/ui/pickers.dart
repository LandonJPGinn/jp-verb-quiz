import 'package:flutter/material.dart';

import '../engine/options.dart';
import 'theme.dart';

/// Pretty label for a conjugation form name ("polite past negative",
/// "te-form", ...).
String prettyForm(String form) {
  if (form == 'te-form') return 'て form';
  if (form == 'dictionary') return 'Dictionary form';
  return form
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// Compact selectable chip used in the customize screen — two-per-row grid
/// (Wrap) instead of long single-column checkbox lists.
class SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColors.outlineDark : AppColors.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigo : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.indigo : border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 17,
              color: selected ? Colors.white : border,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid of select chips, two per row.
class SelectChipGrid extends StatelessWidget {
  final List<MapEntry<String, String>> entries; // key -> label
  final bool Function(String key) valueOf;
  final void Function(String key, bool value) onChanged;

  const SelectChipGrid({
    super.key,
    required this.entries,
    required this.valueOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3.4,
      children: [
        for (final e in entries)
          SelectChip(
            label: e.value,
            selected: valueOf(e.key),
            onTap: () => onChanged(e.key, !valueOf(e.key)),
          ),
      ],
    );
  }
}

/// Compact bottom-sheet picker for Question Focus (replaces the fullscreen
/// DropdownButton menu).
Future<String?> showFocusPicker(BuildContext context, String current) async {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final result = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
        ),
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: dark ? AppColors.outlineDark : AppColors.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Question focus',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  for (final e in focusOptions.entries)
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(e.value),
                      trailing: e.key == current
                          ? const Icon(
                              Icons.check,
                              color: AppColors.indigo,
                              size: 20,
                            )
                          : null,
                      onTap: () => Navigator.pop(sheetContext, e.key),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return result; // may be null (dismissed)
}

/// Card container with a small header used across the customize screen.
class SettingsCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const SettingsCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
