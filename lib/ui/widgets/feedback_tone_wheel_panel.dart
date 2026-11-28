import 'package:material_ui/material_ui.dart';

import '../../core/syllable_models.dart';
import 'pitch_contour_painter.dart';

/// Post-submit grading summary, Target/Guess playback, and 1-6 Tone Wheel.
class FeedbackToneWheelPanel extends StatelessWidget {
  const FeedbackToneWheelPanel({
    super.key,
    required this.result,
    this.activeClipIndex,
    required this.onPlayTarget,
    required this.onPlayGuess,
    required this.onPlayToneEntry,
    required this.onNext,
  });

  final GradingResult result;
  final int? activeClipIndex;
  final VoidCallback onPlayTarget;
  final VoidCallback onPlayGuess;
  final void Function(SyllableEntry entry) onPlayToneEntry;
  final VoidCallback onNext;

  List<ComponentGrade> _displayGrades() {
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
                    overrideLabel: i == 1
                        ? PracticeStep.syllableFinal.shortLabel
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ComparisonActionButton(
                    icon: Icons.volume_up,
                    roleLabel: 'Target',
                    syllable: result.target.syllable,
                    tone: result.target.tone,
                    isCheckedTone: isChecked,
                    accentColor: scheme.primary,
                    fillColor: scheme.primaryContainer,
                    isPlaying: activeClipIndex == 0,
                    isDimmed: activeClipIndex != null && activeClipIndex != 0,
                    onPressed: onPlayTarget,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ComparisonActionButton(
                    icon: Icons.hearing,
                    roleLabel: 'Guess',
                    syllable: result.guessedKey.syllable,
                    tone: result.guessedKey.tone,
                    isCheckedTone: const {
                      'p',
                      't',
                      'k',
                    }.contains(result.guessedKey.coda),
                    accentColor: scheme.error,
                    fillColor: scheme.errorContainer,
                    contourColor: scheme.secondary,
                    isPlaying: activeClipIndex == 1,
                    isDimmed: activeClipIndex != null && activeClipIndex != 1,
                    onPressed: result.isGuessPlayable ? onPlayGuess : null,
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: PitchContourBox(
                              tone: t,
                              isCheckedTone: isChecked,
                              width: 28,
                              height: 14,
                              showGuides: false,
                            ),
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
    this.overrideLabel,
  });

  final ComponentGrade grade;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = grade.isCorrect;
    final exp = grade.expected.isEmpty
        ? ComponentType.noneLabel
        : grade.expected;
    final guess = grade.guessed.isEmpty
        ? ComponentType.noneLabel
        : grade.guessed;
    final compLabel = overrideLabel ?? grade.component.shortLabel;
    final text = ok
        ? '$compLabel: $exp ✓'
        : '$compLabel: $guess → $exp ✗';
    return Chip(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      label: Text(text, style: const TextStyle(fontSize: 13)),
      backgroundColor: ok
          ? scheme.primaryContainer.withValues(alpha: 0.6)
          : scheme.errorContainer,
    );
  }
}

class _ComparisonActionButton extends StatelessWidget {
  const _ComparisonActionButton({
    required this.icon,
    required this.roleLabel,
    required this.syllable,
    required this.tone,
    required this.isCheckedTone,
    required this.accentColor,
    required this.fillColor,
    this.contourColor,
    required this.isPlaying,
    required this.isDimmed,
    required this.onPressed,
  });

  final IconData icon;
  final String roleLabel;
  final String syllable;
  final int tone;
  final bool isCheckedTone;
  final Color accentColor;
  final Color fillColor;
  final Color? contourColor;
  final bool isPlaying;
  final bool isDimmed;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: isDimmed ? 0.52 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: isPlaying
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            backgroundColor: isPlaying ? fillColor : null,
            side: BorderSide(
              color: isPlaying ? accentColor : scheme.outline,
              width: isPlaying ? 2.5 : 1.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 4),
                  Text(roleLabel, style: const TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        syllable,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PitchContourBox(
                    tone: tone,
                    isCheckedTone: isCheckedTone,
                    width: 28,
                    height: 16,
                    color: contourColor,
                    showGuides: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
