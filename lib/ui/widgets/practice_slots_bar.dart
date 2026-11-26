import 'package:material_ui/material_ui.dart';

import '../../core/syllable_models.dart';
import '../../state/quiz_controller.dart';

/// Displays the progressively built Jyutping syllable with tappable step segments.
class PracticeSlotsBar extends StatelessWidget {
  const PracticeSlotsBar({
    super.key,
    required this.draft,
    required this.activeStep,
    required this.result,
    required this.isTonesOnlyLocked,
    required this.onSelectStep,
  });

  final DraftInputState draft;
  final PracticeStep activeStep;
  final GradingResult? result;
  final bool isTonesOnlyLocked;
  final void Function(PracticeStep step) onSelectStep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = result?.autoNormalizedSyllabicNasal ?? false;

    final startGrade = result?.grades[ComponentType.initial];
    final ComponentGrade? endingGrade = result == null
        ? null
        : ComponentGrade(
            component: ComponentType.coda,
            expected:
                '${result!.grades[ComponentType.nucleus]!.expected}${result!.grades[ComponentType.coda]!.expected}',
            guessed:
                '${result!.grades[ComponentType.nucleus]!.guessed}${result!.grades[ComponentType.coda]!.guessed}',
            isCorrect:
                result!.grades[ComponentType.nucleus]!.isCorrect &&
                result!.grades[ComponentType.coda]!.isCorrect,
          );
    final toneGrade = result?.grades[ComponentType.tone];

    final showEmptyInitialSymbol = draft.initial == '' &&
        ((!isTonesOnlyLocked && result == null) ||
            (startGrade != null && !startGrade.isCorrect));

    final String startText;
    if (draft.initial == null) {
      startText = '_';
    } else if (draft.initial!.isEmpty) {
      startText = showEmptyInitialSymbol ? '∅' : '';
    } else {
      startText = draft.initial!;
    }

    final endingText = draft.nucleus == null
        ? '__'
        : '${draft.nucleus}${draft.coda ?? ''}';
    final toneText = draft.tone == null ? '_' : '${draft.tone}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (startText.isNotEmpty)
                  _SyllableSegment(
                    key: const ValueKey('practice-slot-start'),
                    text: startText,
                    isPlaceholder: draft.initial == null,
                    isMutedSymbol: draft.initial == '',
                    active: result == null && activeStep == PracticeStep.start,
                    grade: startGrade,
                    locked: isTonesOnlyLocked,
                    onTap: () => onSelectStep(PracticeStep.start),
                  ),
                _SyllableSegment(
                  key: const ValueKey('practice-slot-ending'),
                  text: endingText,
                  isPlaceholder: draft.nucleus == null,
                  isMutedSymbol: false,
                  active: result == null && activeStep == PracticeStep.ending,
                  grade: endingGrade,
                  locked: isTonesOnlyLocked,
                  onTap: () => onSelectStep(PracticeStep.ending),
                ),
                _SyllableSegment(
                  key: const ValueKey('practice-slot-tone'),
                  text: toneText,
                  isPlaceholder: draft.tone == null,
                  isMutedSymbol: false,
                  active: result == null && activeStep == PracticeStep.tone,
                  grade: toneGrade,
                  locked: false,
                  fontSize: 20,
                  onTap: () => onSelectStep(PracticeStep.tone),
                ),
              ],
            ),
          ),
        ),
        if (normalized)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Hummed syllable ${result!.guessedKey.syllable}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _SyllableSegment extends StatelessWidget {
  const _SyllableSegment({
    super.key,
    required this.text,
    required this.isPlaceholder,
    required this.isMutedSymbol,
    required this.active,
    required this.grade,
    required this.locked,
    required this.onTap,
    this.fontSize = 24,
  });

  final String text;
  final bool isPlaceholder;
  final bool isMutedSymbol;
  final bool active;
  final ComponentGrade? grade;
  final bool locked;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color textColor;
    if (grade != null) {
      textColor = grade!.isCorrect ? scheme.primary : scheme.error;
    } else if (active) {
      textColor = scheme.primary;
    } else if (isPlaceholder || isMutedSymbol) {
      textColor = scheme.onSurfaceVariant;
    } else {
      textColor = scheme.onSurface;
    }

    return InkWell(
      onTap: grade == null && !locked ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: active
              ? scheme.primaryContainer.withValues(alpha: 0.45)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: active
              ? Border(bottom: BorderSide(color: scheme.primary, width: 2.5))
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isPlaceholder ? FontWeight.w500 : FontWeight.w700,
            color: textColor,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
