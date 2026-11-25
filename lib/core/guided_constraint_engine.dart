import 'syllable_models.dart';

/// Computes dynamically enabled keys in Guided Mode from the active pool.
class GuidedConstraintEngine {
  GuidedConstraintEngine(this.pool);

  final List<SyllableEntry> pool;

  /// Allowed initial tokens given currently selected nucleus, coda, and tone.
  Set<String> allowedInitials(DraftInputState draft) {
    final result = <String>{};
    for (final entry in pool) {
      if (_matchesOther(
        entry,
        nucleus: draft.nucleus,
        coda: draft.coda,
        tone: draft.tone,
      )) {
        result.add(entry.initial);
        // Allow learners to tap m/ng in Initial when syllabic nasal exists.
        if (entry.nucleus.isEmpty &&
            entry.initial.isEmpty &&
            (entry.coda == 'm' || entry.coda == 'ng') &&
            draft.nucleus == null &&
            draft.coda == null) {
          result.add(entry.coda);
        }
      }
    }
    return result;
  }

  /// Allowed vowel nuclei given currently selected initial, coda, and tone.
  Set<String> allowedNuclei(DraftInputState draft) {
    final result = <String>{};
    for (final entry in pool) {
      if (entry.nucleus.isEmpty) continue;
      if (_matchesOther(
        entry,
        initial: draft.initial,
        coda: draft.coda,
        tone: draft.tone,
      )) {
        result.add(entry.nucleus);
      }
    }
    return result;
  }

  /// Allowed codas given currently selected initial, nucleus, and tone.
  Set<String> allowedCodas(DraftInputState draft) {
    final result = <String>{};
    for (final entry in pool) {
      if (_matchesOther(
        entry,
        initial: draft.initial,
        nucleus: draft.nucleus,
        tone: draft.tone,
      )) {
        result.add(entry.coda);
      }
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
