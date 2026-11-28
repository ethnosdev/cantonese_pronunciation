import 'jyutping_constants.dart';

/// Dataset realism tier matching jyutnet pri-* classifications.
enum DatasetTier {
  pri0('pri0', 'Standard (2,520)'),
  pri0And1('pri0_1', 'All Tones (4,344)'),
  allRecorded('all', 'All Recorded (5,358)');

  const DatasetTier(this.id, this.label);

  final String id;
  final String label;

  bool includesPriority(int priority) {
    switch (this) {
      case DatasetTier.pri0:
        return priority == 0;
      case DatasetTier.pri0And1:
        return priority == 0 || priority == 1;
      case DatasetTier.allRecorded:
        return true;
    }
  }

  static DatasetTier fromId(String? id) {
    for (final tier in DatasetTier.values) {
      if (tier.id == id) return tier;
    }
    return DatasetTier.pri0;
  }
}

/// Keyboard input constraint behavior during quizzes.
enum ConstraintMode {
  test('test', 'Test Mode'),
  guided('guided', 'Guided Mode');

  const ConstraintMode(this.id, this.label);

  final String id;
  final String label;

  static ConstraintMode fromId(String? id) {
    for (final mode in ConstraintMode.values) {
      if (mode.id == id) return mode;
    }
    return ConstraintMode.test;
  }
}

/// Active keyboard step in the 3-step syllable builder.
enum PracticeStep {
  initial(headerLabel: 'Initial consonant', shortLabel: 'Initial'),
  syllableFinal(headerLabel: 'Final', shortLabel: 'Final'),
  tone(headerLabel: 'Tone', shortLabel: 'Tone');

  const PracticeStep({
    required this.headerLabel,
    required this.shortLabel,
  });

  final String headerLabel;
  final String shortLabel;
}

/// The four phonological slots of a Jyutping syllable.
enum ComponentType {
  initial(
    shortLabel: 'Initial',
    fullLabel: 'Initial consonant',
    promptLabel: 'initial consonant',
  ),
  nucleus(
    shortLabel: 'Vowel',
    fullLabel: 'Vowel',
    promptLabel: 'vowel',
  ),
  coda(
    shortLabel: 'Coda',
    fullLabel: 'Coda',
    promptLabel: 'coda',
  ),
  tone(
    shortLabel: 'Tone',
    fullLabel: 'Tone',
    promptLabel: 'tone',
  );

  const ComponentType({
    required this.shortLabel,
    required this.fullLabel,
    required this.promptLabel,
  });

  final String shortLabel;
  final String fullLabel;
  final String promptLabel;

  static const String noneLabel = 'None';
  static const String emptySymbol = '∅';

  static ComponentType fromName(String name) {
    return ComponentType.values.firstWhere((e) => e.name == name);
  }
}

/// Parameterized Focus Filter for quiz syllable sampling and UI locking.
sealed class FocusFilter {
  const FocusFilter();

  String get id;
  String get label;

  bool matches(SyllableEntry entry);

  static FocusFilter fromId(String? raw) {
    if (raw == null || raw == 'all') return const AllFilter();
    if (raw == 'tones_only') return const TonesOnlyFilter();
    if (raw.startsWith('initial:')) {
      final name = raw.substring('initial:'.length);
      for (final g in ConfusableInitialGroup.values) {
        if (g.name == name) return InitialContrastFilter(g);
      }
    }
    if (raw.startsWith('final:')) {
      final name = raw.substring('final:'.length);
      for (final g in ConfusableFinalGroup.values) {
        if (g.name == name) return FinalContrastFilter(g);
      }
    }
    return const AllFilter();
  }
}

final class AllFilter extends FocusFilter {
  const AllFilter();

  @override
  String get id => 'all';

  @override
  String get label => 'All Syllables';

  @override
  bool matches(SyllableEntry entry) => true;

  @override
  bool operator ==(Object other) => other is AllFilter;

  @override
  int get hashCode => id.hashCode;
}

final class TonesOnlyFilter extends FocusFilter {
  const TonesOnlyFilter();

  @override
  String get id => 'tones_only';

  @override
  String get label => 'Tones Only';

  @override
  bool matches(SyllableEntry entry) => true;

  @override
  bool operator ==(Object other) => other is TonesOnlyFilter;

  @override
  int get hashCode => id.hashCode;
}

final class InitialContrastFilter extends FocusFilter {
  const InitialContrastFilter(this.group);

  final ConfusableInitialGroup group;

  @override
  String get id => 'initial:${group.name}';

  @override
  String get label => 'Initials: ${group.label}';

  @override
  bool matches(SyllableEntry entry) => group.initials.contains(entry.initial);

  @override
  bool operator ==(Object other) =>
      other is InitialContrastFilter && other.group == group;

  @override
  int get hashCode => Object.hash(id, group);
}

final class FinalContrastFilter extends FocusFilter {
  const FinalContrastFilter(this.group);

  final ConfusableFinalGroup group;

  @override
  String get id => 'final:${group.name}';

  @override
  String get label => 'Finals: ${group.label}';

  @override
  bool matches(SyllableEntry entry) {
    switch (group) {
      case ConfusableFinalGroup.aaA:
        return entry.nucleus == 'aa' || entry.nucleus == 'a';
      case ConfusableFinalGroup.oeEoYu:
        return entry.nucleus == 'oe' ||
            entry.nucleus == 'eo' ||
            entry.nucleus == 'yu';
      case ConfusableFinalGroup.nNg:
        return entry.coda == 'n' ||
            (entry.coda == 'ng' && entry.nucleus.isNotEmpty);
      case ConfusableFinalGroup.mNNg:
        return entry.coda == 'm' || entry.coda == 'n' || entry.coda == 'ng';
      case ConfusableFinalGroup.ptk:
        return entry.coda == 'p' || entry.coda == 't' || entry.coda == 'k';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FinalContrastFilter && other.group == group;

  @override
  int get hashCode => Object.hash(id, group);
}

/// Canonical four-part syllable identity.
class SyllableKey {
  const SyllableKey({
    required this.initial,
    required this.nucleus,
    required this.coda,
    required this.tone,
  });

  final String initial;
  final String nucleus;
  final String coda;
  final int tone;

  String get base => '$initial$nucleus$coda';
  String get syllable => '$base$tone';

  @override
  bool operator ==(Object other) =>
      other is SyllableKey &&
      other.initial == initial &&
      other.nucleus == nucleus &&
      other.coda == coda &&
      other.tone == tone;

  @override
  int get hashCode => Object.hash(initial, nucleus, coda, tone);

  @override
  String toString() => syllable;
}

/// Recorded syllable row loaded from SQLite.
class SyllableEntry {
  const SyllableEntry({
    required this.syllable,
    required this.path,
    required this.initial,
    required this.nucleus,
    required this.coda,
    required this.tone,
    required this.initialGroup,
    required this.priority,
  });

  final String syllable;
  final String path;
  final String initial;
  final String nucleus;
  final String coda;
  final int tone;
  final int initialGroup;
  final int priority;

  SyllableKey get key => SyllableKey(
    initial: initial,
    nucleus: nucleus,
    coda: coda,
    tone: tone,
  );

  String get base => '$initial$nucleus$coda';

  Map<String, Object?> toDbRow() => {
    'syllable': syllable,
    'path': path,
    'initial': initial,
    'nucleus': nucleus,
    'coda': coda,
    'tone': tone,
    'initial_group': initialGroup,
    'priority': priority,
  };

  factory SyllableEntry.fromDbRow(Map<String, Object?> row) {
    return SyllableEntry(
      syllable: row['syllable'] as String,
      path: row['path'] as String,
      initial: row['initial'] as String,
      nucleus: row['nucleus'] as String,
      coda: row['coda'] as String,
      tone: row['tone'] as int,
      initialGroup: row['initial_group'] as int,
      priority: row['priority'] as int,
    );
  }
}

/// Mutable-like four-slot UI draft where null indicates an unselected slot.
class DraftInputState {
  const DraftInputState({
    this.initial,
    this.nucleus,
    this.coda,
    this.tone,
  });

  final String? initial;
  final String? nucleus;
  final String? coda;
  final int? tone;

  static const _sentinel = Object();

  DraftInputState copyWith({
    Object? initial = _sentinel,
    Object? nucleus = _sentinel,
    Object? coda = _sentinel,
    Object? tone = _sentinel,
  }) {
    return DraftInputState(
      initial: identical(initial, _sentinel) ? this.initial : initial as String?,
      nucleus: identical(nucleus, _sentinel) ? this.nucleus : nucleus as String?,
      coda: identical(coda, _sentinel) ? this.coda : coda as String?,
      tone: identical(tone, _sentinel) ? this.tone : tone as int?,
    );
  }

  /// True when the user entered m or ng in the Initial slot without vowel/coda.
  bool get hasAutoNormalizedSyllabicNasal =>
      (initial == 'm' || initial == 'ng') &&
      (nucleus == null || nucleus == '') &&
      (coda == null || coda == '');

  /// True when slots represent a valid syllabic nasal (direct or normalized).
  bool get isValidSyllabicNasal {
    if (nucleus != null && nucleus!.isNotEmpty) return false;
    final directCoda =
        (initial == null || initial == '' || initial == 'h') &&
        (coda == 'm' || coda == 'ng');
    return directCoda || hasAutoNormalizedSyllabicNasal;
  }

  /// Minimum structural validity required to submit a guess.
  bool get canSubmit =>
      tone != null && ((nucleus != null && nucleus!.isNotEmpty) || isValidSyllabicNasal);

  /// Converts draft slots into a canonical SyllableKey.
  SyllableKey normalizeForSubmission() {
    if (hasAutoNormalizedSyllabicNasal) {
      return SyllableKey(
        initial: '',
        nucleus: '',
        coda: initial!,
        tone: tone!,
      );
    }
    return SyllableKey(
      initial: initial ?? '',
      nucleus: nucleus ?? '',
      coda: coda ?? '',
      tone: tone!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DraftInputState &&
      other.initial == initial &&
      other.nucleus == nucleus &&
      other.coda == coda &&
      other.tone == tone;

  @override
  int get hashCode => Object.hash(initial, nucleus, coda, tone);
}

/// Aggregated confusion counter for one (component, expected, guessed) tuple.
class ConfusionStat {
  const ConfusionStat({
    required this.component,
    required this.expected,
    required this.guessed,
    required this.count,
  });

  final ComponentType component;
  final String expected;
  final String guessed;
  final int count;
}

/// Accuracy summary for one phonological component type.
class ComponentAccuracy {
  const ComponentAccuracy({
    required this.component,
    required this.correct,
    required this.total,
  });

  final ComponentType component;
  final int correct;
  final int total;

  double get rate => total == 0 ? 0.0 : correct / total;
}

/// Grading outcome for a single submitted component.
class ComponentGrade {
  const ComponentGrade({
    required this.component,
    required this.expected,
    required this.guessed,
    required this.isCorrect,
  });

  final ComponentType component;
  final String expected;
  final String guessed;
  final bool isCorrect;
}

/// Complete feedback payload returned after submitting a quiz turn.
class GradingResult {
  const GradingResult({
    required this.target,
    required this.guessedKey,
    required this.guessedEntry,
    required this.grades,
    required this.statsComponents,
    required this.autoNormalizedSyllabicNasal,
    required this.toneFamily,
  });

  final SyllableEntry target;
  final SyllableKey guessedKey;
  final SyllableEntry? guessedEntry;
  final Map<ComponentType, ComponentGrade> grades;
  final List<ComponentType> statsComponents;
  final bool autoNormalizedSyllabicNasal;
  final List<SyllableEntry> toneFamily;

  bool get isAllCorrect => grades.values.every((g) => g.isCorrect);
  bool get isGuessPlayable => guessedEntry != null;
}
