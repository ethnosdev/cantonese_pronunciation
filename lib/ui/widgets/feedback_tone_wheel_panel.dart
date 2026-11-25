import 'package:material_ui/material_ui.dart';

import '../../core/jyutping_constants.dart';
import '../../core/syllable_models.dart';

/// Post-submit grading summary, Target/Guess playback, and 1-6 Tone Wheel.
class FeedbackToneWheelPanel extends StatelessWidget {
  const FeedbackToneWheelPanel({
    super.key,
    required this.result,
    required this.onPlayTarget,
    required this.onPlayGuess,
    required this.onPlayToneEntry,
    required this.onNext,
  });

  final GradingResult result;
  final VoidCallback onPlayTarget;
  final VoidCallback onPlayGuess;
  final void Function(SyllableEntry entry) onPlayToneEntry;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final toneByNumber = {for (final e in result.toneFamily) e.tone: e};

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  result.isAllCorrect ? Icons.check_circle : Icons.info_outline,
                  color: result.isAllCorrect
                      ? Colors.green.shade700
                      : scheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.isAllCorrect
                        ? 'Correct: ${result.target.syllable}'
                        : 'Target: ${result.target.syllable}  •  '
                              'Guess: ${result.guessedKey.syllable}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final comp in ComponentType.values)
                  _ComponentBadge(grade: result.grades[comp]!),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPlayTarget,
                    icon: const Icon(Icons.volume_up, size: 18),
                    label: Text('Target (${result.target.syllable})'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: result.isGuessPlayable ? onPlayGuess : null,
                    icon: const Icon(Icons.hearing, size: 18),
                    label: Text('Guess (${result.guessedKey.syllable})'),
                  ),
                ),
              ],
            ),
            if (!result.isGuessPlayable)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'This combination (${result.guessedKey.syllable}) does not '
                  'exist in the dataset.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Tone Wheel (1–6)',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var t = 1; t <= 6; t++) ...[
                  if (t > 1) const SizedBox(width: 4),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: toneByNumber[t] != null
                          ? () => onPlayToneEntry(toneByNumber[t]!)
                          : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: Size.zero,
                        backgroundColor: t == result.target.tone
                            ? scheme.primaryContainer
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$t',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            JyutpingConstants.tonePitchLabels[t]!,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: onNext,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComponentBadge extends StatelessWidget {
  const _ComponentBadge({required this.grade});

  final ComponentGrade grade;

  @override
  Widget build(BuildContext context) {
    final ok = grade.isCorrect;
    final exp = grade.expected.isEmpty ? '∅' : grade.expected;
    final guess = grade.guessed.isEmpty ? '∅' : grade.guessed;
    final text = ok
        ? '${grade.component.label}: $exp ✓'
        : '${grade.component.label}: $guess → $exp';
    return Chip(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      label: Text(text, style: const TextStyle(fontSize: 11)),
      backgroundColor: ok
          ? Colors.green.withValues(alpha: 0.14)
          : Theme.of(context).colorScheme.errorContainer,
    );
  }
}
