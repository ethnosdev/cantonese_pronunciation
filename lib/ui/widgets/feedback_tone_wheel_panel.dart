import 'package:material_ui/material_ui.dart';

import '../../core/jyutping_constants.dart';
import '../../core/syllable_models.dart';
import 'pitch_contour_painter.dart';

/// Post-submit grading summary, Target/Guess playback, and 1-6 Tone Wheel.
class FeedbackToneWheelPanel extends StatelessWidget {
  const FeedbackToneWheelPanel({
    super.key,
    required this.result,
    this.useBeginnerLabels = false,
    this.useThreeBeginnerBadges = false,
    required this.onPlayTarget,
    required this.onPlayGuess,
    required this.onPlayToneEntry,
    required this.onNext,
  });

  final GradingResult result;
  final bool useBeginnerLabels;
  final bool useThreeBeginnerBadges;
  final VoidCallback onPlayTarget;
  final VoidCallback onPlayGuess;
  final void Function(SyllableEntry entry) onPlayToneEntry;
  final VoidCallback onNext;

  List<ComponentGrade> _displayGrades() {
    if (!useThreeBeginnerBadges) {
      return [for (final comp in ComponentType.values) result.grades[comp]!];
    }
    final iGrade = result.grades[ComponentType.initial]!;
    final nGrade = result.grades[ComponentType.nucleus]!;
    final cGrade = result.grades[ComponentType.coda]!;
    final tGrade = result.grades[ComponentType.tone]!;
    return [
      iGrade,
      ComponentGrade(
        component: ComponentType.coda,
        expected: '${nGrade.expected}${cGrade.expected}',
        guessed: '${nGrade.guessed}${cGrade.guessed}',
        isCorrect: nGrade.isCorrect && cGrade.isCorrect,
      ),
      tGrade,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final toneByNumber = {for (final e in result.toneFamily) e.tone: e};
    final isChecked = const {'p', 't', 'k'}.contains(result.target.coda);
    final beginnerMode = useBeginnerLabels || useThreeBeginnerBadges;
    final badges = _displayGrades();

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
                  result.isAllCorrect ? Icons.check_circle : Icons.cancel,
                  color: result.isAllCorrect ? scheme.primary : scheme.error,
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
                for (var i = 0; i < badges.length; i++)
                  _ComponentBadge(
                    grade: badges[i],
                    useBeginnerLabels: beginnerMode,
                    overrideLabel: useThreeBeginnerBadges && i == 1
                        ? 'Ending'
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPlayTarget,
                    icon: const Icon(Icons.volume_up, size: 18),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Target (${result.target.syllable})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        PitchContourBox(
                          tone: result.target.tone,
                          isCheckedTone: isChecked,
                          width: 28,
                          height: 16,
                          showGuides: false,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: result.isGuessPlayable ? onPlayGuess : null,
                    icon: const Icon(Icons.hearing, size: 18),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Guess (${result.guessedKey.syllable})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        PitchContourBox(
                          tone: result.guessedKey.tone,
                          isCheckedTone: const {
                            'p',
                            't',
                            'k',
                          }.contains(result.guessedKey.coda),
                          width: 28,
                          height: 16,
                          color: scheme.secondary,
                          showGuides: false,
                        ),
                      ],
                    ),
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
                          if (beginnerMode)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: PitchContourBox(
                                tone: t,
                                isCheckedTone: isChecked,
                                width: 28,
                                height: 14,
                                showGuides: false,
                              ),
                            )
                          else
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
  const _ComponentBadge({
    required this.grade,
    required this.useBeginnerLabels,
    this.overrideLabel,
  });

  final ComponentGrade grade;
  final bool useBeginnerLabels;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = grade.isCorrect;
    final emptyLabel = useBeginnerLabels ? 'None' : '∅';
    final exp = grade.expected.isEmpty ? emptyLabel : grade.expected;
    final guess = grade.guessed.isEmpty ? emptyLabel : grade.guessed;
    final compLabel =
        overrideLabel ??
        grade.component.displayLabel(useBeginnerLabels: useBeginnerLabels);
    final text = ok
        ? '$compLabel: $exp ✓'
        : '$compLabel: $guess → $exp ✗';
    return Chip(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      label: Text(text, style: const TextStyle(fontSize: 11)),
      backgroundColor: ok
          ? scheme.primaryContainer.withValues(alpha: 0.6)
          : scheme.errorContainer,
    );
  }
}
