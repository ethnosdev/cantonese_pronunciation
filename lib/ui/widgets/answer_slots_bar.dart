import 'package:material_ui/material_ui.dart';

import '../../core/jyutping_constants.dart';
import '../../core/syllable_models.dart';

/// Displays the four independent phonological answer slots above the keyboard.
class AnswerSlotsBar extends StatelessWidget {
  const AnswerSlotsBar({
    super.key,
    required this.draft,
    required this.result,
    required this.isTonesOnlyLocked,
    required this.onClearSlot,
  });

  final DraftInputState draft;
  final GradingResult? result;
  final bool isTonesOnlyLocked;
  final void Function(ComponentType component) onClearSlot;

  @override
  Widget build(BuildContext context) {
    final normalized = result?.autoNormalizedSyllabicNasal ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _SlotTile(
                label: 'Initial',
                value: _displaySlot(
                  ComponentType.initial,
                  draft.initial,
                  locked: isTonesOnlyLocked,
                ),
                grade: result?.grades[ComponentType.initial],
                locked: isTonesOnlyLocked,
                onTap: () => onClearSlot(ComponentType.initial),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _SlotTile(
                label: 'Nucleus',
                value: _displaySlot(
                  ComponentType.nucleus,
                  draft.nucleus,
                  locked: isTonesOnlyLocked,
                ),
                grade: result?.grades[ComponentType.nucleus],
                locked: isTonesOnlyLocked,
                onTap: () => onClearSlot(ComponentType.nucleus),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _SlotTile(
                label: 'Coda',
                value: _displaySlot(
                  ComponentType.coda,
                  draft.coda,
                  locked: isTonesOnlyLocked,
                ),
                grade: result?.grades[ComponentType.coda],
                locked: isTonesOnlyLocked,
                onTap: () => onClearSlot(ComponentType.coda),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _SlotTile(
                label: 'Tone',
                value: draft.tone == null
                    ? '—'
                    : '${draft.tone} (${JyutpingConstants.tonePitchLabels[draft.tone]})',
                grade: result?.grades[ComponentType.tone],
                locked: false,
                onTap: () => onClearSlot(ComponentType.tone),
              ),
            ),
          ],
        ),
        if (normalized)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Normalized to syllabic nasal ${result!.guessedKey.syllable}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  String _displaySlot(
    ComponentType type,
    String? raw, {
    required bool locked,
  }) {
    if (raw == null) return '—';
    if (raw.isEmpty) {
      if (type == ComponentType.initial) return '∅';
      return locked ? '—' : 'open';
    }
    return raw;
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.label,
    required this.value,
    required this.grade,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final String value;
  final ComponentGrade? grade;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color borderColor = scheme.outlineVariant;
    Color bgColor = scheme.surfaceContainerLow;
    if (grade != null) {
      borderColor = grade!.isCorrect ? Colors.green.shade600 : scheme.error;
      bgColor = grade!.isCorrect
          ? Colors.green.withValues(alpha: 0.12)
          : scheme.errorContainer.withValues(alpha: 0.45);
    } else if (locked) {
      bgColor = scheme.surfaceContainerHighest;
    }

    return InkWell(
      onTap: grade == null && !locked ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (locked) ...[
                  const SizedBox(width: 2),
                  const Icon(Icons.lock, size: 10),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
