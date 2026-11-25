import 'syllable_models.dart';

/// Grades submitted 4-slot drafts independently and resolves Tone Wheel options.
class SyllableGrader {
  const SyllableGrader._();

  static GradingResult grade({
    required SyllableEntry target,
    required DraftInputState draft,
    required FocusFilter filter,
    List<ComponentType>? statsComponents,
    required SyllableEntry? Function(SyllableKey key) lookupEntry,
    required List<SyllableEntry> Function(
      String initial,
      String nucleus,
      String coda,
    )
    lookupToneFamily,
  }) {
    final autoNormalized = draft.hasAutoNormalizedSyllabicNasal;
    final guessedKey = draft.normalizeForSubmission();

    final grades = <ComponentType, ComponentGrade>{
      ComponentType.initial: ComponentGrade(
        component: ComponentType.initial,
        expected: target.initial,
        guessed: guessedKey.initial,
        isCorrect: target.initial == guessedKey.initial,
      ),
      ComponentType.nucleus: ComponentGrade(
        component: ComponentType.nucleus,
        expected: target.nucleus,
        guessed: guessedKey.nucleus,
        isCorrect: target.nucleus == guessedKey.nucleus,
      ),
      ComponentType.coda: ComponentGrade(
        component: ComponentType.coda,
        expected: target.coda,
        guessed: guessedKey.coda,
        isCorrect: target.coda == guessedKey.coda,
      ),
      ComponentType.tone: ComponentGrade(
        component: ComponentType.tone,
        expected: target.tone.toString(),
        guessed: guessedKey.tone.toString(),
        isCorrect: target.tone == guessedKey.tone,
      ),
    };

    // Exclude pre-filled slots from stats during Tones Only or partial-slot drills.
    final resolvedStatsComponents =
        statsComponents ??
        (filter is TonesOnlyFilter
            ? const [ComponentType.tone]
            : ComponentType.values);

    final guessedEntry = lookupEntry(guessedKey);
    final toneFamily = lookupToneFamily(
      target.initial,
      target.nucleus,
      target.coda,
    );

    return GradingResult(
      target: target,
      guessedKey: guessedKey,
      guessedEntry: guessedEntry,
      grades: grades,
      statsComponents: resolvedStatsComponents,
      autoNormalizedSyllabicNasal: autoNormalized,
      toneFamily: toneFamily,
    );
  }
}
