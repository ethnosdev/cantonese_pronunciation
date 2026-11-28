import 'syllable_models.dart';

/// Rendering and interaction format for a lesson or trial.
enum ExerciseFormat {
  hearAndCompare,
  sameDifferent,
  choiceCards,
  slotAssembly,
}

/// Identifies whether a trial came from core lesson practice or Daily Review.
enum DeckSource { core, review }

/// Progression status of a lesson in SQLite `lesson_progress`.
enum LessonStatus {
  locked,
  unlocked,
  completed;

  static LessonStatus fromDb(String? raw) {
    for (final s in LessonStatus.values) {
      if (s.name == raw) return s;
    }
    return LessonStatus.locked;
  }
}

/// Active phase inside a running lesson or Daily Review session.
enum SessionPhase {
  hearAndCompare,
  warmup,
  trial,
  feedback,
  summary,
}

/// Slot constraint configuration for Unit 7 assembly lessons.
class SlotMask {
  const SlotMask({
    this.lockedComponents = const {},
    this.isGuided = true,
  });

  final Set<ComponentType> lockedComponents;
  final bool isGuided;

  List<ComponentType> get statsComponents => ComponentType.values
      .where((c) => !lockedComponents.contains(c))
      .toList(growable: false);
}

/// One schedulable contrast skill seeded into `review_items` upon lesson pass.
class ContrastSkill {
  const ContrastSkill({
    required this.lessonId,
    required this.targetType,
    required this.targetValue,
    required this.displayLabel,
  });

  final String lessonId;
  final String targetType; // 'tone' | 'initial' | 'nucleus' | 'coda' | 'syllable'
  final String targetValue;
  final String displayLabel;

  String get skillId => '$lessonId:$targetType:$targetValue';
}

/// Reference sound card shown during an optional Hear-and-Compare intro.
class HearAndCompareItem {
  const HearAndCompareItem({
    required this.value,
    required this.label,
    required this.hint,
    this.preferredSyllable,
    this.tone,
    this.isCheckedTone = false,
  });

  final String value;
  final String label;
  final String hint;
  final String? preferredSyllable;
  final int? tone;
  final bool isCheckedTone;
}

/// Resolved Hear-and-Compare card bound to a playable corpus syllable.
class ResolvedHearAndCompareCard {
  const ResolvedHearAndCompareCard({
    required this.item,
    required this.entry,
  });

  final HearAndCompareItem item;
  final SyllableEntry entry;
}

/// Warmup definition preceding graded core trials in early lessons.
class WarmupSpec {
  const WarmupSpec({
    this.hearAndCompareItems = const [],
    this.sameDifferentCount = 0,
    this.sameDifferentPrompt,
    this.differentProperty,
  });

  final List<HearAndCompareItem> hearAndCompareItems;
  final int sameDifferentCount;
  final String? sameDifferentPrompt;
  final ComponentType? differentProperty;
}

/// Grouping unit on the Learning Path Home screen.
class UnitSpec {
  const UnitSpec({
    required this.id,
    required this.number,
    required this.title,
  });

  final String id;
  final int number;
  final String title;
}

/// Static definition for one of the 28 beginner curriculum lessons.
class LessonSpec {
  const LessonSpec({
    required this.id,
    required this.unitId,
    required this.numberLabel,
    required this.title,
    required this.introSummary,
    this.phoneticsNote,
    this.trialPrompt,
    required this.poolTier,
    required this.format,
    required this.coreCount,
    required this.poolPredicate,
    this.targetComponent,
    this.differentProperty,
    this.choices = const [],
    this.choiceGroups,
    this.showContoursOnButtons = false,
    this.pairedChoicesRequired = false,
    this.stratifiedByChoice = true,
    this.warmup,
    this.slotMask,
    this.seedSkills = const [],
    this.cumulativeReviewUpToUnit,
  }) : assert(
         format != ExerciseFormat.slotAssembly ||
             (trialPrompt != null && trialPrompt != ''),
       );

  final String id;
  final String unitId;
  final String numberLabel;
  final String title;
  final String introSummary;
  final String? phoneticsNote;
  final String? trialPrompt;
  final DatasetTier poolTier;
  final ExerciseFormat format;
  final int coreCount;
  final bool Function(SyllableEntry entry) poolPredicate;
  final ComponentType? targetComponent;
  final ComponentType? differentProperty;
  final List<String> choices;
  final List<List<String>>? choiceGroups;
  final bool showContoursOnButtons;
  final bool pairedChoicesRequired;
  final bool stratifiedByChoice;
  final WarmupSpec? warmup;
  final SlotMask? slotMask;
  final List<ContrastSkill> seedSkills;

  /// Non-null for cumulative unit checkpoint reviews (e.g. `2` reviews Units 1–2).
  final int? cumulativeReviewUpToUnit;

  bool get isCumulativeReview => cumulativeReviewUpToUnit != null;
}

/// Sentinel settings marker for standalone Daily Review sessions.
class DailyReviewSpec {
  const DailyReviewSpec._();

  static const int trialTargetCount = 10;
  static const int maxGradedTurns = 16;
  static const String title = 'Daily Review';
}

/// Persisted progression record from `lesson_progress`.
class LessonProgressRecord {
  const LessonProgressRecord({
    required this.lessonId,
    required this.status,
    required this.bestAccuracy,
    required this.attemptsCount,
    required this.lastCompletedAt,
    required this.updatedAt,
  });

  final String lessonId;
  final LessonStatus status;
  final double bestAccuracy;
  final int attemptsCount;
  final DateTime? lastCompletedAt;
  final DateTime updatedAt;
}

/// Persisted contrast-skill review state from `review_items`.
class ReviewItem {
  const ReviewItem({
    required this.skillId,
    required this.lessonId,
    required this.targetType,
    required this.targetValue,
    required this.intervalStage,
    required this.dueAt,
    required this.lapses,
    required this.lastReviewedAt,
  });

  final String skillId;
  final String lessonId;
  final String targetType;
  final String targetValue;
  final int intervalStage;
  final DateTime dueAt;
  final int lapses;
  final DateTime lastReviewedAt;

  ReviewItem copyWith({
    int? intervalStage,
    DateTime? dueAt,
    int? lapses,
    DateTime? lastReviewedAt,
  }) {
    return ReviewItem(
      skillId: skillId,
      lessonId: lessonId,
      targetType: targetType,
      targetValue: targetValue,
      intervalStage: intervalStage ?? this.intervalStage,
      dueAt: dueAt ?? this.dueAt,
      lapses: lapses ?? this.lapses,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}

/// One tappable choice card presented in choice-card lessons and Daily Review.
class ChoiceOption {
  const ChoiceOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.tone,
    this.syllableEntry,
    this.isCheckedTone = false,
  });

  final String value;
  final String label;
  final String? subtitle;
  final int? tone;
  final SyllableEntry? syllableEntry;
  final bool isCheckedTone;
}

/// Executable trial inside a `LessonSession` queue.
class LessonTrial {
  const LessonTrial({
    required this.trialId,
    required this.target,
    required this.promptText,
    required this.format,
    required this.deckSource,
    required this.sourceLessonId,
    required this.statsComponents,
    this.pairTarget,
    this.isSamePair,
    this.differentProperty,
    this.isRetry = false,
    this.skillId,
    this.choices = const [],
    this.slotMask,
    this.showContoursOnButtons = false,
    this.expectedChoiceValue = '',
  });

  final String trialId;
  final SyllableEntry target;
  final SyllableEntry? pairTarget;
  final bool? isSamePair;
  final ComponentType? differentProperty;
  final String promptText;
  final ExerciseFormat format;
  final DeckSource deckSource;
  final bool isRetry;
  final String sourceLessonId;
  final String? skillId;
  final List<ChoiceOption> choices;
  final SlotMask? slotMask;
  final List<ComponentType> statsComponents;
  final bool showContoursOnButtons;
  final String expectedChoiceValue;

  LessonTrial asRetry(int retryIndex) {
    return LessonTrial(
      trialId: '${trialId}_retry_$retryIndex',
      target: target,
      pairTarget: pairTarget,
      isSamePair: isSamePair,
      differentProperty: differentProperty,
      promptText: promptText,
      format: format,
      deckSource: deckSource,
      isRetry: true,
      sourceLessonId: sourceLessonId,
      skillId: skillId,
      choices: choices,
      slotMask: slotMask,
      statsComponents: statsComponents,
      showContoursOnButtons: showContoursOnButtons,
      expectedChoiceValue: expectedChoiceValue,
    );
  }
}

/// Feedback generated immediately after submitting a trial.
class TrialFeedback {
  const TrialFeedback({
    required this.isCorrect,
    required this.target,
    required this.promptText,
    required this.showToneContours,
    this.selectedChoice,
    this.expectedChoice,
    this.guessedEntry,
    this.gradingResult,
    this.pairEntry,
    this.isSamePair,
    this.userPickedSame,
    this.differentProperty,
    this.isWarmup = false,
  });

  final bool isCorrect;
  final SyllableEntry target;
  final String promptText;
  final bool showToneContours;
  final ChoiceOption? selectedChoice;
  final ChoiceOption? expectedChoice;
  final SyllableEntry? guessedEntry;
  final GradingResult? gradingResult;
  final SyllableEntry? pairEntry;
  final bool? isSamePair;
  final bool? userPickedSame;
  final ComponentType? differentProperty;
  final bool isWarmup;
}

/// Interval change summary item shown at the end of a Daily Review session.
class ReviewSkillUpdate {
  const ReviewSkillUpdate({
    required this.skillId,
    required this.displayLabel,
    required this.newIntervalDays,
    required this.lapsed,
  });

  final String skillId;
  final String displayLabel;
  final int newIntervalDays;
  final bool lapsed;
}

/// Final outcome computed when a lesson or Daily Review finishes.
class SessionOutcome {
  const SessionOutcome({
    required this.isDailyReview,
    required this.coreCorrect,
    required this.coreTotal,
    required this.accuracy,
    required this.passed,
    this.lessonId,
    this.unlockedNextLessonId,
    this.reviewedCount = 0,
    this.advancedSkillCount = 0,
    this.resetSkillCount = 0,
    this.seededSkillCount = 0,
    this.reviewUpdates = const [],
  });

  final bool isDailyReview;
  final String? lessonId;
  final int coreCorrect;
  final int coreTotal;
  final double accuracy;
  final bool passed;
  final String? unlockedNextLessonId;
  final int reviewedCount;
  final int advancedSkillCount;
  final int resetSkillCount;
  final int seededSkillCount;
  final List<ReviewSkillUpdate> reviewUpdates;
}
