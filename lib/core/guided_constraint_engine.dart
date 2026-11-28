import 'jyutping_constants.dart';
import 'syllable_models.dart';

/// Computes dynamically enabled keys in Guided Mode from the active pool.
class GuidedConstraintEngine {
  GuidedConstraintEngine(this.pool);

  final List<SyllableEntry> pool;

  /// Allowed 3-step initials; filters by [lockedEnding] only when Final is locked.
  Set<String> allowedStarts({String? lockedEnding}) {
    final result = <String>{};
    for (final entry in pool) {
      if (lockedEnding != null && '${entry.nucleus}${entry.coda}' != lockedEnding) {
        continue;
      }
      result.add(entry.initial);
    }
    return result;
  }

  /// Allowed 57-Final strings given currently selected [initial].
  Set<String> allowedEndings(String? initial) {
    final result = <String>{};
    for (final entry in pool) {
      if (initial != null && entry.initial != initial) continue;
      result.add('${entry.nucleus}${entry.coda}');
    }
    return result;
  }

  /// Allowed tones; keeps all 6 tones enabled when [preventToneLeaking] is set.
  Set<int> allowedTones(
    DraftInputState draft,
    FocusFilter filter, {
    bool preventToneLeaking = false,
  }) {
    if (preventToneLeaking || filter is TonesOnlyFilter) {
      return {1, 2, 3, 4, 5, 6};
    }
    final result = <int>{};
    for (final entry in pool) {
      if (_matchesOther(
        entry,
        initial: draft.initial,
        nucleus: draft.nucleus,
        coda: draft.coda,
      )) {
        result.add(entry.tone);
      }
      // Syllabic nasal alias when user selected m/ng in the Initial slot.
      if (draft.hasAutoNormalizedSyllabicNasal &&
          entry.initial.isEmpty &&
          entry.nucleus.isEmpty &&
          entry.coda == draft.initial) {
        result.add(entry.tone);
      }
    }
    return result;
  }

  /// Returns true when draft is structurally valid and exists in the active pool.
  bool canSubmit(
    DraftInputState draft,
    FocusFilter filter, {
    bool preventToneLeaking = false,
  }) {
    if (!draft.canSubmit) return false;
    final normalized = draft.normalizeForSubmission();
    if (preventToneLeaking || filter is TonesOnlyFilter) {
      return pool.any(
        (e) =>
            e.initial == normalized.initial &&
            e.nucleus == normalized.nucleus &&
            e.coda == normalized.coda,
      );
    }
    return pool.any((e) => e.key == normalized);
  }

  bool _matchesOther(
    SyllableEntry entry, {
    String? initial,
    String? nucleus,
    String? coda,
    int? tone,
  }) {
    if (initial != null && entry.initial != initial) return false;
    if (nucleus != null && entry.nucleus != nucleus) return false;
    if (coda != null && entry.coda != coda) return false;
    if (tone != null && entry.tone != tone) return false;
    return true;
  }
}

/// Outcome of a 3-step transition helper action.
class ThreeStepTransition {
  const ThreeStepTransition({
    required this.draft,
    required this.nextStep,
    this.shouldSubmit = false,
  });

  final DraftInputState draft;
  final PracticeStep nextStep;
  final bool shouldSubmit;
}

/// Shared 3-step transition and validation logic for Practice and Unit 7 lessons.
class ThreeStepAssemblyHelper {
  const ThreeStepAssemblyHelper._();

  static String? selectedEndingFor(DraftInputState draft) =>
      draft.nucleus == null ? null : '${draft.nucleus}${draft.coda ?? ''}';

  static PracticeStep firstUnlockedStep(Set<PracticeStep> lockedSteps) {
    for (final step in PracticeStep.values) {
      if (!lockedSteps.contains(step)) return step;
    }
    return PracticeStep.tone;
  }

  static ThreeStepTransition selectStart({
    required DraftInputState draft,
    required PracticeStep currentStep,
    required String initial,
    required GuidedConstraintEngine engine,
    required Set<PracticeStep> lockedSteps,
    required bool isGuided,
  }) {
    if (lockedSteps.contains(PracticeStep.initial)) {
      return ThreeStepTransition(draft: draft, nextStep: currentStep);
    }
    var nextNucleus = draft.nucleus;
    var nextCoda = draft.coda;
    if (!lockedSteps.contains(PracticeStep.syllableFinal) &&
        nextNucleus != null &&
        isGuided) {
      final ending = '$nextNucleus${nextCoda ?? ''}';
      final valid = engine.pool.any(
        (e) => e.initial == initial && '${e.nucleus}${e.coda}' == ending,
      );
      if (!valid) {
        nextNucleus = null;
        nextCoda = null;
      }
    }
    final nextDraft = draft.copyWith(
      initial: initial,
      nucleus: nextNucleus,
      coda: nextCoda,
      tone: lockedSteps.contains(PracticeStep.tone) ? draft.tone : null,
    );
    final PracticeStep nextStep;
    if (!lockedSteps.contains(PracticeStep.syllableFinal) &&
        nextNucleus == null) {
      nextStep = PracticeStep.syllableFinal;
    } else if (!lockedSteps.contains(PracticeStep.tone)) {
      nextStep = PracticeStep.tone;
    } else {
      nextStep = currentStep;
    }
    return ThreeStepTransition(draft: nextDraft, nextStep: nextStep);
  }

  static ThreeStepTransition selectEnding({
    required DraftInputState draft,
    required PracticeStep currentStep,
    required String finalStr,
    required Set<PracticeStep> lockedSteps,
  }) {
    if (lockedSteps.contains(PracticeStep.syllableFinal)) {
      return ThreeStepTransition(draft: draft, nextStep: currentStep);
    }
    final (nucleus, coda) = JyutpingConstants.splitFinal(finalStr);
    final nextDraft = draft.copyWith(
      nucleus: nucleus,
      coda: coda,
      tone: lockedSteps.contains(PracticeStep.tone) ? draft.tone : null,
    );
    final PracticeStep nextStep;
    if (!lockedSteps.contains(PracticeStep.initial) && draft.initial == null) {
      nextStep = PracticeStep.initial;
    } else if (!lockedSteps.contains(PracticeStep.tone)) {
      nextStep = PracticeStep.tone;
    } else {
      nextStep = currentStep;
    }
    return ThreeStepTransition(draft: nextDraft, nextStep: nextStep);
  }

  static bool canSubmitAssembly({
    required DraftInputState draft,
    required GuidedConstraintEngine engine,
    required FocusFilter filter,
    required Set<PracticeStep> lockedSteps,
    required bool isGuided,
    required bool preventToneLeaking,
  }) {
    if (!lockedSteps.contains(PracticeStep.initial) && draft.initial == null) {
      return false;
    }
    if (!lockedSteps.contains(PracticeStep.syllableFinal) &&
        draft.nucleus == null &&
        !draft.hasAutoNormalizedSyllabicNasal) {
      return false;
    }
    if (!lockedSteps.contains(PracticeStep.tone) && draft.tone == null) {
      return false;
    }
    if (isGuided) {
      return engine.canSubmit(
        draft,
        filter,
        preventToneLeaking: preventToneLeaking,
      );
    }
    return draft.canSubmit;
  }

  static ThreeStepTransition selectToneAndSubmit({
    required DraftInputState draft,
    required PracticeStep currentStep,
    required int tone,
    required GuidedConstraintEngine engine,
    required FocusFilter filter,
    required Set<PracticeStep> lockedSteps,
    required bool isGuided,
    required bool preventToneLeaking,
  }) {
    if (!lockedSteps.contains(PracticeStep.initial) && draft.initial == null) {
      return ThreeStepTransition(
        draft: draft,
        nextStep: PracticeStep.initial,
        shouldSubmit: false,
      );
    }
    if (!lockedSteps.contains(PracticeStep.syllableFinal) &&
        draft.nucleus == null &&
        !draft.hasAutoNormalizedSyllabicNasal) {
      return ThreeStepTransition(
        draft: draft,
        nextStep: PracticeStep.syllableFinal,
        shouldSubmit: false,
      );
    }
    final nextDraft = lockedSteps.contains(PracticeStep.tone)
        ? draft
        : draft.copyWith(tone: tone);
    final ready = canSubmitAssembly(
      draft: nextDraft,
      engine: engine,
      filter: filter,
      lockedSteps: lockedSteps,
      isGuided: isGuided,
      preventToneLeaking: preventToneLeaking,
    );
    return ThreeStepTransition(
      draft: nextDraft,
      nextStep: currentStep,
      shouldSubmit: ready,
    );
  }
}
