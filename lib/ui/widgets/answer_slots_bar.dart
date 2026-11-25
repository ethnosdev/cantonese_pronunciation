import 'package:material_ui/material_ui.dart';

import '../../core/curriculum.dart';
import '../../core/jyutping_constants.dart';
import '../../core/syllable_models.dart';

/// Displays the four independent phonological answer slots above the keyboard.
class AnswerSlotsBar extends StatelessWidget {
  const AnswerSlotsBar({
    super.key,
    required this.draft,
    required this.result,
    this.isTonesOnlyLocked = false,
    this.useBeginnerLabels = false,
    this.lockedComponents = const {},
    required this.onClearSlot,
  });

  final DraftInputState draft;
  final GradingResult? result;
  final bool isTonesOnlyLocked;
  final bool useBeginnerLabels;
  final Set<ComponentType> lockedComponents;
  final void Function(ComponentType component) onClearSlot;

  bool _isLocked(ComponentType comp) {
    if (isTonesOnlyLocked && comp != ComponentType.tone) return true;
    return lockedComponents.contains(comp);
  }

  @override
  Widget build(BuildContext context) {
    final normalized = result?.autoNormalizedSyllabicNasal ?? false;
    final initialLocked = _isLocked(ComponentType.initial);
    final nucleusLocked = _isLocked(ComponentType.nucleus);
    final codaLocked = _isLocked(ComponentType.coda);
    final toneLocked = _isLocked(ComponentType.tone);
    final toneValue = draft.tone == null
        ? '—'
        : (useBeginnerLabels
              ? Curriculum.plainToneLabel(draft.tone!)
              : '${draft.tone} (${JyutpingConstants.tonePitchLabels[draft.tone]})');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _SlotTile(
                label: ComponentType.initial.displayLabel(
                  useBeginnerLabels: useBeginnerLabels,
                ),
                value: _displaySlot(
                  ComponentType.initial,
                  draft.initial,
                ),
                grade: result?.grades[ComponentType.initial],
                locked: initialLocked,
                onTap: () => onClearSlot(ComponentType.initial),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _SlotTile(
                label: ComponentType.nucleus.displayLabel(
                  useBeginnerLabels: useBeginnerLabels,
                ),
                value: _displaySlot(
                  ComponentType.nucleus,
                  draft.nucleus,
                ),
                grade: result?.grades[ComponentType.nucleus],
                locked: nucleusLocked,
                onTap: () => onClearSlot(ComponentType.nucleus),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _SlotTile(
                label: ComponentType.coda.displayLabel(
                  useBeginnerLabels: useBeginnerLabels,
                ),
                value: _displaySlot(
                  ComponentType.coda,
                  draft.coda,
                ),
                grade: result?.grades[ComponentType.coda],
                locked: codaLocked,
                onTap: () => onClearSlot(ComponentType.coda),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _SlotTile(
                label: ComponentType.tone.displayLabel(
                  useBeginnerLabels: useBeginnerLabels,
                ),
                value: toneValue,
                grade: result?.grades[ComponentType.tone],
                locked: toneLocked,
                onTap: () => onClearSlot(ComponentType.tone),
              ),
            ),
          ],
        ),
        if (normalized)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              useBeginnerLabels
                  ? 'Hummed syllable ${result!.guessedKey.syllable}'
                  : 'Normalized to syllabic nasal ${result!.guessedKey.syllable}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  String _displaySlot(ComponentType type, String? raw) {
    if (raw == null) return '—';
    if (raw.isEmpty) {
      if (useBeginnerLabels) return 'None';
      if (type == ComponentType.initial) return '∅';
      return 'open';
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
      borderColor = grade!.isCorrect ? scheme.primary : scheme.error;
      bgColor = grade!.isCorrect
          ? scheme.primaryContainer.withValues(alpha: 0.45)
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
                ] else if (grade != null) ...[
                  const SizedBox(width: 2),
                  Icon(
                    grade!.isCorrect ? Icons.check : Icons.close,
                    size: 11,
                    color: grade!.isCorrect ? scheme.primary : scheme.error,
                  ),
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
