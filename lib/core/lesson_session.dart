import 'dart:math';

import 'curriculum.dart';
import 'lesson_spec.dart';
import 'review_scheduler.dart';
import 'syllable_grader.dart';
import 'syllable_models.dart';

/// Pure-Dart finite session runner for Lessons 1.1–7.4 and standalone Daily Review.
class LessonSession {
  LessonSession._({
    required this.isDailyReview,
    required this.lessonSpec,
    required this.hearAndCompareCards,
    required this.warmupTrials,
    required List<LessonTrial> gradedQueue,
    required Map<SyllableKey, SyllableEntry> catalogByKey,
    required Map<String, List<SyllableEntry>> toneFamiliesByBase,
    required this.scheduler,
    required Map<String, ReviewItem> reviewItemsBySkillId,
  }) : _gradedQueue = gradedQueue,
       _catalogByKey = Map.of(catalogByKey),
       _toneFamiliesByBase = Map.of(toneFamiliesByBase),
       _reviewItemsBySkillId = Map.of(reviewItemsBySkillId),
       _initialCoreCount = isDailyReview ? 0 : gradedQueue.length {
    if (hearAndCompareCards.isNotEmpty) {
      _phase = SessionPhase.hearAndCompare;
    } else if (warmupTrials.isNotEmpty) {
      _phase = SessionPhase.warmup;
    } else if (_gradedQueue.isNotEmpty) {
      _phase = SessionPhase.trial;
    } else {
      _phase = SessionPhase.summary;
    }
  }

  /// Maximum extra missed-question retry turns inserted in a curriculum lesson.
  static const int maxLessonRetries = 6;

  final bool isDailyReview;
  final LessonSpec? lessonSpec;
  final List<ResolvedHearAndCompareCard> hearAndCompareCards;
  final List<LessonTrial> warmupTrials;
  final List<LessonTrial> _gradedQueue;
  final Map<SyllableKey, SyllableEntry> _catalogByKey;
  final Map<String, List<SyllableEntry>> _toneFamiliesByBase;
  final ReviewScheduler scheduler;
  final Map<String, ReviewItem> _reviewItemsBySkillId;
  final int _initialCoreCount;

  final List<GradingResult> _pendingStats = [];
  final Map<String, bool> _reviewFirstAttemptPassed = {};
  final Set<String> _retriedOriginIds = {};

  late SessionPhase _phase;
  int _warmupIndex = 0;
  int _gradedIndex = 0;
  int _retryCounter = 0;
  int _coreFirstAttemptCorrect = 0;
  int _submittedGradedCount = 0;
  TrialFeedback? _currentFeedback;
  SessionOutcome? _outcome;

  SessionPhase get phase => _phase;
  int get warmupIndex => _warmupIndex;
  int get gradedIndex => _gradedIndex;
  int get gradedTotal => _gradedQueue.length;
  int get warmupTotal => warmupTrials.length;
  int get submittedCount => _submittedGradedCount;
  TrialFeedback? get currentFeedback => _currentFeedback;
  SessionOutcome? get outcome => _outcome;
  List<GradingResult> get pendingStats => List.unmodifiable(_pendingStats);

  /// Current active trial (`warmup` or `trial`), or null in `hearAndCompare`/`summary`.
  LessonTrial? get currentTrial {
    if (_phase == SessionPhase.warmup && _warmupIndex < warmupTrials.length) {
      return warmupTrials[_warmupIndex];
    }
    if ((_phase == SessionPhase.trial || _phase == SessionPhase.feedback) &&
        _currentFeedback != null &&
        _currentFeedback!.isWarmup &&
        _warmupIndex < warmupTrials.length) {
      return warmupTrials[_warmupIndex];
    }
    if ((_phase == SessionPhase.trial || _phase == SessionPhase.feedback) &&
        _gradedIndex < _gradedQueue.length) {
      return _gradedQueue[_gradedIndex];
    }
    return null;
  }

  /// Fractional progress `(0.0..1.0)` across active steps (warmups + graded queue).
  double get progressFraction {
    final total = warmupTrials.length + _gradedQueue.length;
    if (total == 0) return 1.0;
    if (_phase == SessionPhase.summary) return 1.0;
    final done = _phase == SessionPhase.hearAndCompare
        ? 0
        : _warmupIndex + _gradedIndex;
    return (done / total).clamp(0.0, 1.0);
  }

  /// Starts a single-format standard lesson session (Units 1–7).
  factory LessonSession.startLesson(
    LessonSpec spec, {
    required List<SyllableEntry> catalog,
    Random? random,
    ReviewScheduler? scheduler,
  }) {
    final rng = random ?? Random();
    final sched = scheduler ?? ReviewScheduler();
    final byKey = {for (final e in catalog) e.key: e};
    final families = _groupToneFamilies(catalog);
    final rawPool = Curriculum.filterPool(spec, catalog);
    final pairedPool = Curriculum.pairedEntries(spec, rawPool, byKey);
    final usablePool = pairedPool.isNotEmpty ? pairedPool : rawPool;

    final cards = _resolveHearAndCompareCards(spec, catalog, usablePool);
    final warmups = _buildWarmups(spec, usablePool, rng);
    final coreTrials = _buildCoreTrials(spec, usablePool, byKey, rng);

    return LessonSession._(
      isDailyReview: false,
      lessonSpec: spec,
      hearAndCompareCards: cards,
      warmupTrials: warmups,
      gradedQueue: coreTrials,
      catalogByKey: byKey,
      toneFamiliesByBase: families,
      scheduler: sched,
      reviewItemsBySkillId: const {},
    );
  }

  /// Starts a standalone Daily Review session from overdue `review_items`.
  factory LessonSession.startDailyReview(
    List<ReviewItem> dueItems, {
    required List<SyllableEntry> catalog,
    required bool hideToneContours,
    Random? random,
    ReviewScheduler? scheduler,
  }) {
    final rng = random ?? Random();
    final sched = scheduler ?? ReviewScheduler();
    final byKey = {for (final e in catalog) e.key: e};
    final families = _groupToneFamilies(catalog);

    final selected = sched.selectDueQueue(
      dueItems,
      limit: DailyReviewSpec.trialTargetCount,
    );
    final trials = <LessonTrial>[];
    final reviewMap = <String, ReviewItem>{};

    for (var i = 0; i < selected.length; i++) {
      final item = selected[i];
      final spec = Curriculum.lessonById(item.lessonId);
      if (spec == null) continue;
      final rawPool = Curriculum.filterPool(spec, catalog);
      final paired = Curriculum.pairedEntries(spec, rawPool, byKey);
      final usable = paired.isNotEmpty ? paired : rawPool;
      final matching = usable.where((e) {
        switch (item.targetType) {
          case 'tone':
            return e.tone.toString() == item.targetValue;
          case 'initial':
            return e.initial == item.targetValue;
          case 'nucleus':
            return e.nucleus == item.targetValue;
          case 'coda':
            return e.coda == item.targetValue;
          case 'syllable':
            return e.base == item.targetValue;
          default:
            return false;
        }
      }).toList();
      final sourceList = matching.isNotEmpty ? matching : usable;
      if (sourceList.isEmpty) continue;
      final target = sourceList[rng.nextInt(sourceList.length)];
      final expectedVal = Curriculum.componentValue(spec, target);
      final choices = Curriculum.choicesForEntry(spec, target)
          .map(
            (val) => Curriculum.buildChoiceOption(
              spec: spec,
              target: target,
              value: val,
              catalogByKey: byKey,
            ),
          )
          .toList(growable: false);
      reviewMap[item.skillId] = item;
      trials.add(
        LessonTrial(
          trialId: 'review_${i}_${item.skillId}',
          target: target,
          promptText: _promptForLesson(spec),
          format: ExerciseFormat.choiceCards,
          deckSource: DeckSource.review,
          sourceLessonId: spec.id,
          skillId: item.skillId,
          choices: choices,
          statsComponents: spec.targetComponent != null
              ? [spec.targetComponent!]
              : const [],
          showContoursOnButtons:
              !hideToneContours && spec.showContoursOnButtons,
          expectedChoiceValue: expectedVal,
        ),
      );
    }

    return LessonSession._(
      isDailyReview: true,
      lessonSpec: null,
      hearAndCompareCards: const [],
      warmupTrials: const [],
      gradedQueue: trials,
      catalogByKey: byKey,
      toneFamiliesByBase: families,
      scheduler: sched,
      reviewItemsBySkillId: reviewMap,
    );
  }

  /// Leaves the Hear-and-Compare screen and starts warmup or core trials.
  void completeHearAndCompare() {
    if (_phase != SessionPhase.hearAndCompare) return;
    if (warmupTrials.isNotEmpty) {
      _phase = SessionPhase.warmup;
    } else if (_gradedQueue.isNotEmpty) {
      _phase = SessionPhase.trial;
    } else {
      _finishSession();
    }
  }

  /// Submits `Same` or `Different` for the current ungraded warmup trial.
  TrialFeedback submitSameDifferent({required bool pickedSame}) {
    final trial = warmupTrials[_warmupIndex];
    final isCorrect = pickedSame == (trial.isSamePair ?? true);
    final feedback = TrialFeedback(
      isCorrect: isCorrect,
      target: trial.target,
      pairEntry: trial.pairTarget,
      isSamePair: trial.isSamePair,
      userPickedSame: pickedSame,
      differentProperty: trial.differentProperty,
      promptText: trial.promptText,
      showToneContours: trial.differentProperty == DifferentProperty.tone,
      isWarmup: true,
    );
    _currentFeedback = feedback;
    _phase = SessionPhase.feedback;
    return feedback;
  }

  /// Submits a tap-to-answer choice card for a graded core or Daily Review trial.
  TrialFeedback submitChoice(ChoiceOption choice) {
    final trial = _gradedQueue[_gradedIndex];
    final isCorrect = choice.value == trial.expectedChoiceValue;
    final expectedOption = trial.choices.firstWhere(
      (c) => c.value == trial.expectedChoiceValue,
      orElse: () => ChoiceOption(
        value: trial.expectedChoiceValue,
        label: trial.expectedChoiceValue,
        syllableEntry: trial.target,
      ),
    );
    final spec = Curriculum.lessonById(trial.sourceLessonId);

    _recordGradedResult(trial, isCorrect: isCorrect);

    if (trial.statsComponents.length == 1 && spec?.targetComponent != null) {
      final comp = spec!.targetComponent!;
      _pendingStats.add(
        GradingResult(
          target: trial.target,
          guessedKey: choice.syllableEntry?.key ?? trial.target.key,
          guessedEntry: choice.syllableEntry,
          grades: {
            comp: ComponentGrade(
              component: comp,
              expected: trial.expectedChoiceValue,
              guessed: choice.value,
              isCorrect: isCorrect,
            ),
          },
          statsComponents: trial.statsComponents,
          autoNormalizedSyllabicNasal: false,
          toneFamily:
              _toneFamiliesByBase[trial.target.base] ?? const <SyllableEntry>[],
        ),
      );
    }

    final feedback = TrialFeedback(
      isCorrect: isCorrect,
      target: trial.target,
      promptText: trial.promptText,
      showToneContours: trial.differentProperty == DifferentProperty.tone ||
          spec?.targetComponent == ComponentType.tone,
      selectedChoice: choice,
      expectedChoice: expectedOption,
      guessedEntry: choice.syllableEntry,
      differentProperty: trial.differentProperty,
      isWarmup: false,
    );
    _currentFeedback = feedback;
    _phase = SessionPhase.feedback;
    return feedback;
  }

  /// Submits a multi-slot keyboard draft for Unit 7 `slotAssembly` trials.
  TrialFeedback submitAssembly(DraftInputState draft) {
    final trial = _gradedQueue[_gradedIndex];
    final result = SyllableGrader.grade(
      target: trial.target,
      draft: draft,
      filter: const AllFilter(),
      statsComponents: trial.statsComponents,
      lookupEntry: (key) => _catalogByKey[key],
      lookupToneFamily: (i, n, c) =>
          _toneFamiliesByBase['$i$n$c'] ?? const <SyllableEntry>[],
    );
    final isCorrect = trial.statsComponents.every(
      (c) => result.grades[c]?.isCorrect ?? false,
    );

    _recordGradedResult(trial, isCorrect: isCorrect);
    _pendingStats.add(result);

    final feedback = TrialFeedback(
      isCorrect: isCorrect,
      target: trial.target,
      promptText: trial.promptText,
      showToneContours: true,
      guessedEntry: result.guessedEntry,
      gradingResult: result,
      isWarmup: false,
    );
    _currentFeedback = feedback;
    _phase = SessionPhase.feedback;
    return feedback;
  }

  /// Advances from feedback to the next warmup, graded trial, or summary.
  void advanceAfterFeedback() {
    if (_phase != SessionPhase.feedback || _currentFeedback == null) return;
    final wasWarmup = _currentFeedback!.isWarmup;
    _currentFeedback = null;

    if (wasWarmup) {
      _warmupIndex++;
      if (_warmupIndex < warmupTrials.length) {
        _phase = SessionPhase.warmup;
      } else if (_gradedQueue.isNotEmpty) {
        _phase = SessionPhase.trial;
      } else {
        _finishSession();
      }
      return;
    }

    _gradedIndex++;
    if (_gradedIndex < _gradedQueue.length) {
      _phase = SessionPhase.trial;
    } else {
      _finishSession();
    }
  }

  /// Returns updated [ReviewItem] records computed from Daily Review outcomes.
  List<ReviewItem> buildUpdatedReviewItems({DateTime? reviewedAt}) {
    if (!isDailyReview) return const [];
    final ts = (reviewedAt ?? scheduler.now()).toUtc();
    final updated = <ReviewItem>[];
    for (final entry in _reviewFirstAttemptPassed.entries) {
      final original = _reviewItemsBySkillId[entry.key];
      if (original == null) continue;
      updated.add(
        scheduler.applyOutcome(
          original,
          passedFirstAttempt: entry.value,
          reviewedAt: ts,
        ),
      );
    }
    return updated;
  }

  void _recordGradedResult(LessonTrial trial, {required bool isCorrect}) {
    _submittedGradedCount++;
    if (!trial.isRetry) {
      if (trial.deckSource == DeckSource.core && isCorrect) {
        _coreFirstAttemptCorrect++;
      } else if (trial.deckSource == DeckSource.review &&
          trial.skillId != null) {
        _reviewFirstAttemptPassed[trial.skillId!] = isCorrect;
      }

      if (!isCorrect && !_retriedOriginIds.contains(trial.trialId)) {
        final remainingAfter = _gradedQueue.length - (_gradedIndex + 1);
        final maxTurns = isDailyReview
            ? DailyReviewSpec.maxGradedTurns
            : _initialCoreCount + maxLessonRetries;
        final underTurnCap = _gradedQueue.length < maxTurns;
        // Skip retry on final turn so back-to-back 0-spacing repeats never occur.
        if (remainingAfter >= 1 && underTurnCap) {
          _retriedOriginIds.add(trial.trialId);
          final insertAt = min(_gradedIndex + 3, _gradedQueue.length);
          _gradedQueue.insert(insertAt, trial.asRetry(++_retryCounter));
        }
      }
    }
  }

  void _finishSession() {
    _phase = SessionPhase.summary;
    if (isDailyReview) {
      final reviewed = _reviewFirstAttemptPassed.length;
      final advanced = _reviewFirstAttemptPassed.values.where((p) => p).length;
      final reset = reviewed - advanced;
      final updates = <ReviewSkillUpdate>[];
      for (final item in buildUpdatedReviewItems()) {
        final passed = _reviewFirstAttemptPassed[item.skillId] ?? false;
        final skillDef = Curriculum.allSeedSkills
            .where((s) => s.skillId == item.skillId)
            .firstOrNull;
        updates.add(
          ReviewSkillUpdate(
            skillId: item.skillId,
            displayLabel: skillDef?.displayLabel ?? item.targetValue,
            newIntervalDays: ReviewScheduler.daysForStage(item.intervalStage),
            lapsed: !passed,
          ),
        );
      }
      _outcome = SessionOutcome(
        isDailyReview: true,
        coreCorrect: advanced,
        coreTotal: reviewed,
        accuracy: reviewed == 0 ? 1.0 : advanced / reviewed,
        passed: true,
        reviewedCount: reviewed,
        advancedSkillCount: advanced,
        resetSkillCount: reset,
        reviewUpdates: updates,
      );
      return;
    }

    final total = _initialCoreCount;
    final accuracy = total == 0 ? 1.0 : _coreFirstAttemptCorrect / total;
    final passed = accuracy >= 0.80;
    final nextId = passed && lessonSpec != null
        ? Curriculum.nextLessonIdAfter(lessonSpec!.id)
        : null;
    _outcome = SessionOutcome(
      isDailyReview: false,
      lessonId: lessonSpec?.id,
      coreCorrect: _coreFirstAttemptCorrect,
      coreTotal: total,
      accuracy: accuracy,
      passed: passed,
      unlockedNextLessonId: nextId,
      seededSkillCount: passed ? (lessonSpec?.seedSkills.length ?? 0) : 0,
    );
  }

  static Map<String, List<SyllableEntry>> _groupToneFamilies(
    List<SyllableEntry> catalog,
  ) {
    final map = <String, List<SyllableEntry>>{};
    for (final e in catalog) {
      map.putIfAbsent(e.base, () => []).add(e);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.tone.compareTo(b.tone));
    }
    return map;
  }

  static List<ResolvedHearAndCompareCard> _resolveHearAndCompareCards(
    LessonSpec spec,
    List<SyllableEntry> catalog,
    List<SyllableEntry> pool,
  ) {
    final items = spec.warmup?.hearAndCompareItems;
    if (items == null || items.isEmpty) return const [];
    final bySyllable = {for (final e in catalog) e.syllable: e};
    final resolved = <ResolvedHearAndCompareCard>[];
    for (final item in items) {
      SyllableEntry? entry = item.preferredSyllable != null
          ? bySyllable[item.preferredSyllable!]
          : null;
      entry ??= pool.firstWhere(
        (e) => Curriculum.componentValue(spec, e) == item.value,
        orElse: () => pool.isNotEmpty ? pool.first : catalog.first,
      );
      resolved.add(ResolvedHearAndCompareCard(item: item, entry: entry));
    }
    return resolved;
  }

  static List<LessonTrial> _buildWarmups(
    LessonSpec spec,
    List<SyllableEntry> pool,
    Random rng,
  ) {
    final warmup = spec.warmup;
    if (warmup == null || warmup.sameDifferentCount <= 0 || pool.length < 2) {
      return const [];
    }
    final prop = warmup.differentProperty ?? DifferentProperty.tone;
    final prompt =
        warmup.sameDifferentPrompt ?? 'Same ${prop.beginnerLabel}?';
    final flags = <bool>[
      for (var i = 0; i < warmup.sameDifferentCount; i++) i.isEven,
    ]..shuffle(rng);

    final trials = <LessonTrial>[];
    for (var i = 0; i < flags.length; i++) {
      final isSame = flags[i];
      final pair = _pickCrossCarrierPair(
        pool: pool,
        prop: prop,
        isSame: isSame,
        rng: rng,
      );
      if (pair == null) continue;
      trials.add(
        LessonTrial(
          trialId: '${spec.id}_warmup_$i',
          target: pair.$1,
          pairTarget: pair.$2,
          isSamePair: isSame,
          differentProperty: prop,
          promptText: prompt,
          format: ExerciseFormat.sameDifferent,
          deckSource: DeckSource.core,
          sourceLessonId: spec.id,
          statsComponents: const [],
          showContoursOnButtons: prop == DifferentProperty.tone,
        ),
      );
    }
    return trials;
  }

  static (SyllableEntry, SyllableEntry)? _pickCrossCarrierPair({
    required List<SyllableEntry> pool,
    required DifferentProperty prop,
    required bool isSame,
    required Random rng,
  }) {
    final shuffled = List<SyllableEntry>.from(pool)..shuffle(rng);
    for (final first in shuffled) {
      final candidates = pool.where((second) {
        if (second.syllable == first.syllable) return false;
        final sameTarget = _propVal(first, prop) == _propVal(second, prop);
        if (isSame) {
          // Cross-carrier: identical target feature on a different base/tone.
          return sameTarget && first.base != second.base ||
              (sameTarget &&
                  prop != DifferentProperty.tone &&
                  first.syllable != second.syllable);
        }
        // Different: differ ONLY on the target dimension when possible.
        return !sameTarget && _sameCarrier(first, second, prop);
      }).toList();
      if (candidates.isNotEmpty) {
        candidates.shuffle(rng);
        // Prefer cross-base on Same whenever available.
        final preferred = isSame
            ? candidates.firstWhere(
                (c) => c.base != first.base,
                orElse: () => candidates.first,
              )
            : candidates.first;
        return (first, preferred);
      }
    }
    // Fallback for small synthetic fixtures: any differing pair if !isSame.
    for (final first in shuffled) {
      for (final second in pool) {
        if (first.syllable == second.syllable) continue;
        final sameTarget = _propVal(first, prop) == _propVal(second, prop);
        if (sameTarget == isSame) {
          return (first, second);
        }
      }
    }
    return null;
  }

  static String _propVal(SyllableEntry e, DifferentProperty prop) {
    switch (prop) {
      case DifferentProperty.tone:
        return e.tone.toString();
      case DifferentProperty.initial:
        return e.initial;
      case DifferentProperty.nucleus:
        return e.nucleus;
      case DifferentProperty.coda:
        return e.coda;
    }
  }

  static bool _sameCarrier(
    SyllableEntry a,
    SyllableEntry b,
    DifferentProperty prop,
  ) {
    switch (prop) {
      case DifferentProperty.tone:
        return a.initial == b.initial &&
            a.nucleus == b.nucleus &&
            a.coda == b.coda;
      case DifferentProperty.initial:
        return a.nucleus == b.nucleus && a.coda == b.coda && a.tone == b.tone;
      case DifferentProperty.nucleus:
        return a.initial == b.initial && a.coda == b.coda && a.tone == b.tone;
      case DifferentProperty.coda:
        return a.initial == b.initial &&
            a.nucleus == b.nucleus &&
            a.tone == b.tone;
    }
  }

  static List<LessonTrial> _buildCoreTrials(
    LessonSpec spec,
    List<SyllableEntry> pool,
    Map<SyllableKey, SyllableEntry> catalogByKey,
    Random rng,
  ) {
    if (pool.isEmpty) return const [];
    final trials = <LessonTrial>[];
    String? lastSyllable;

    List<String>? targetSequence;
    if (spec.stratifiedByChoice &&
        spec.format == ExerciseFormat.choiceCards &&
        spec.choices.isNotEmpty) {
      targetSequence = [
        for (var i = 0; i < spec.coreCount; i++)
          spec.choices[i % spec.choices.length],
      ]..shuffle(rng);
    }

    for (var i = 0; i < spec.coreCount; i++) {
      final target = _sampleTarget(
        spec: spec,
        pool: pool,
        targetChoice: targetSequence?[i],
        previousSyllable: lastSyllable,
        rng: rng,
      );
      lastSyllable = target.syllable;

      if (spec.format == ExerciseFormat.slotAssembly) {
        final mask = spec.slotMask ?? const SlotMask();
        trials.add(
          LessonTrial(
            trialId: '${spec.id}_core_$i',
            target: target,
            promptText: _promptForLesson(spec),
            format: ExerciseFormat.slotAssembly,
            deckSource: DeckSource.core,
            sourceLessonId: spec.id,
            slotMask: mask,
            statsComponents: mask.statsComponents,
            showContoursOnButtons: false,
          ),
        );
      } else {
        final expectedVal = Curriculum.componentValue(spec, target);
        final choices = Curriculum.choicesForEntry(spec, target)
            .map(
              (val) => Curriculum.buildChoiceOption(
                spec: spec,
                target: target,
                value: val,
                catalogByKey: catalogByKey,
              ),
            )
            .toList(growable: false);
        trials.add(
          LessonTrial(
            trialId: '${spec.id}_core_$i',
            target: target,
            promptText: _promptForLesson(spec),
            format: ExerciseFormat.choiceCards,
            deckSource: DeckSource.core,
            sourceLessonId: spec.id,
            differentProperty: spec.differentProperty,
            choices: choices,
            statsComponents: spec.targetComponent != null
                ? [spec.targetComponent!]
                : const [],
            showContoursOnButtons: spec.showContoursOnButtons,
            expectedChoiceValue: expectedVal,
          ),
        );
      }
    }
    return trials;
  }

  static SyllableEntry _sampleTarget({
    required LessonSpec spec,
    required List<SyllableEntry> pool,
    required String? targetChoice,
    required String? previousSyllable,
    required Random rng,
  }) {
    if (targetChoice != null) {
      final matching = pool
          .where((e) => Curriculum.componentValue(spec, e) == targetChoice)
          .toList();
      if (matching.isNotEmpty) {
        final nonRepeat = matching
            .where((e) => e.syllable != previousSyllable)
            .toList();
        final pickFrom = nonRepeat.isNotEmpty ? nonRepeat : matching;
        return pickFrom[rng.nextInt(pickFrom.length)];
      }
    }
    final nonRepeat = pool
        .where((e) => e.syllable != previousSyllable)
        .toList();
    final pickFrom = nonRepeat.isNotEmpty ? nonRepeat : pool;
    return pickFrom[rng.nextInt(pickFrom.length)];
  }

  static String _promptForLesson(LessonSpec spec) {
    switch (spec.format) {
      case ExerciseFormat.choiceCards:
        switch (spec.targetComponent) {
          case ComponentType.tone:
            return 'Which Tone do you hear?';
          case ComponentType.initial:
            return 'Which Start sound do you hear?';
          case ComponentType.nucleus:
            return 'Which Vowel do you hear?';
          case ComponentType.coda:
            return 'Which Ending do you hear?';
          case null:
            return 'Which syllable do you hear?';
        }
      case ExerciseFormat.slotAssembly:
        return spec.cue;
      case ExerciseFormat.hearAndCompare:
      case ExerciseFormat.sameDifferent:
        return spec.cue;
    }
  }
}
