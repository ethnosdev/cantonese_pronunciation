import 'dart:io';
import 'dart:math';

import 'package:cantonese_pronunciation/core/curriculum.dart';
import 'package:cantonese_pronunciation/core/lesson_session.dart';
import 'package:cantonese_pronunciation/core/lesson_spec.dart';
import 'package:cantonese_pronunciation/core/review_scheduler.dart';
import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:cantonese_pronunciation/data/database_helper.dart';
import 'package:cantonese_pronunciation/data/progress_repository.dart';
import 'package:cantonese_pronunciation/data/stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

List<SyllableEntry> _testCatalog() {
  final list = <SyllableEntry>[];
  void add(String i, String n, String c, List<int> tones, {int pri = 0}) {
    for (final t in tones) {
      final syl = '$i$n$c$t';
      list.add(
        SyllableEntry(
          syllable: syl,
          path: '$n/$t/$syl.opus',
          initial: i,
          nucleus: n,
          coda: c,
          tone: t,
          initialGroup: 0,
          priority: pri,
        ),
      );
    }
  }

  for (final base in const ['baa', 'daa', 'saa']) {
    final i = base[0];
    final n = base.substring(1);
    add(i, n, '', [1, 2, 3, 4, 5, 6], pri: 0);
  }
  add('b', 'aa', 'k', [1, 3, 6], pri: 0);
  return list;
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper dbHelper;
  late ProgressRepository progressRepo;
  late StatsRepository statsRepo;
  late DateTime currentNow;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_srs_test_');
    currentNow = DateTime.utc(2026, 11, 25, 9, 0);
    dbHelper = DatabaseHelper(
      factory: databaseFactoryFfiNoIsolate,
      supportDirProvider: () async => tempDir,
    );
    progressRepo = ProgressRepository(dbHelper, clock: () => currentNow);
    statsRepo = StatsRepository(dbHelper);
    await progressRepo.ensureLesson1Unlocked();
  });

  tearDown(() async {
    await dbHelper.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('LessonSession mastery threshold (80%), bounded retries, and Same/Diff warmups', () {
    final catalog = _testCatalog();
    final spec = Curriculum.lessonById('u1_l1_high_vs_low')!;

    // Fail path: 12/20 correct first attempts = 60% (< 80%), with 8 misses capped at +6 retries.
    final failSession = LessonSession.startLesson(
      spec,
      catalog: catalog,
      random: Random(7),
      scheduler: ReviewScheduler(clock: () => currentNow),
    );
    expect(failSession.phase, SessionPhase.hearAndCompare);
    failSession.completeHearAndCompare();
    expect(failSession.phase, SessionPhase.warmup);
    expect(failSession.warmupTrials.length, 2);

    // Complete 2 ungraded warmups (including 1 intentional miss to verify unretried).
    for (var i = 0; i < 2; i++) {
      final w = failSession.currentTrial!;
      expect(w.pairTarget, isNotNull);
      expect(w.target.syllable, isNot(w.pairTarget!.syllable));
      failSession.submitSameDifferent(pickedSame: i == 0);
      failSession.advanceAfterFeedback();
    }
    expect(failSession.phase, SessionPhase.trial);

    var firstAttemptsSeen = 0;
    while (failSession.phase == SessionPhase.trial) {
      final t = failSession.currentTrial!;
      final pickCorrect = t.isRetry || firstAttemptsSeen >= 8;
      if (!t.isRetry) firstAttemptsSeen++;
      final chosen = pickCorrect
          ? t.choices.firstWhere((c) => c.value == t.expectedChoiceValue)
          : t.choices.firstWhere((c) => c.value != t.expectedChoiceValue);
      failSession.submitChoice(chosen);
      failSession.advanceAfterFeedback();
    }

    expect(failSession.phase, SessionPhase.summary);
    expect(failSession.outcome!.passed, isFalse);
    expect(failSession.outcome!.coreCorrect, 12);
    expect(failSession.outcome!.coreTotal, 20);
    // Retries happen at most once per missed item and cap at +6 extra turns (26 total).
    expect(failSession.gradedTotal, 26);
    // Warmups never enter confusion_stats.
    expect(failSession.pendingStats.length, failSession.gradedTotal);

    // Pass path: 19/20 = 95% (>= 80%). Final turn miss does NOT create 0-spacing retry.
    final passSession = LessonSession.startLesson(
      spec,
      catalog: catalog,
      random: Random(11),
      scheduler: ReviewScheduler(clock: () => currentNow),
    );
    passSession.completeHearAndCompare();
    while (passSession.phase == SessionPhase.warmup) {
      passSession.submitSameDifferent(pickedSame: true);
      passSession.advanceAfterFeedback();
    }
    var seen = 0;
    while (passSession.phase == SessionPhase.trial) {
      final t = passSession.currentTrial!;
      final isFinalTurn = seen == 19 && !t.isRetry;
      if (!t.isRetry) seen++;
      final chosen = isFinalTurn
          ? t.choices.firstWhere((c) => c.value != t.expectedChoiceValue)
          : t.choices.firstWhere((c) => c.value == t.expectedChoiceValue);
      passSession.submitChoice(chosen);
      passSession.advanceAfterFeedback();
    }
    expect(passSession.outcome!.passed, isTrue);
    expect(passSession.outcome!.coreCorrect, 19);
    expect(passSession.gradedTotal, 20); // final-turn miss did not re-queue
  });

  test('SRS interval progression, replay INSERT OR IGNORE safety, and Daily Review isolation', () async {
    final spec1 = Curriculum.lessonById('u1_l1_high_vs_low')!;

    // Fail u1_l1: stays unlocked, u1_l2 remains locked, 0 review skills seeded.
    await progressRepo.completeLessonAttempt(
      lessonId: spec1.id,
      accuracy: 0.75,
      passed: false,
      nextLessonId: 'u1_l2_rising_2',
      skillsToSeed: spec1.seedSkills,
    );
    var prog = await progressRepo.loadAllLessonProgress();
    expect(prog[spec1.id]?.status, LessonStatus.unlocked);
    expect(prog['u1_l2_rising_2'], isNull);
    expect(await progressRepo.countDueReviewItems(), 0);

    // Pass u1_l1: marks completed, unlocks u1_l2, seeds tone:1 and tone:4 due +1d.
    await progressRepo.completeLessonAttempt(
      lessonId: spec1.id,
      accuracy: 0.875,
      passed: true,
      nextLessonId: 'u1_l2_rising_2',
      skillsToSeed: spec1.seedSkills,
    );
    prog = await progressRepo.loadAllLessonProgress();
    expect(prog[spec1.id]?.status, LessonStatus.completed);
    expect(prog['u1_l2_rising_2']?.status, LessonStatus.unlocked);

    // Advance 1 day: both skills become due.
    currentNow = currentNow.add(const Duration(days: 1));
    final due = await progressRepo.loadDueReviewItems();
    expect(due.length, 2);

    // Run standalone Daily Review: tone:1 passes (1d->3d), tone:4 misses (1d lapse=1).
    final catalog = _testCatalog();
    final reviewSession = LessonSession.startDailyReview(
      due,
      catalog: catalog,
      hideToneContours: false,
      random: Random(3),
      scheduler: ReviewScheduler(clock: () => currentNow),
    );
    expect(reviewSession.isDailyReview, isTrue);
    while (reviewSession.phase == SessionPhase.trial) {
      final t = reviewSession.currentTrial!;
      final isTone1 = !t.isRetry && t.skillId == 'u1_l1_high_vs_low:tone:1';
      final chosen = isTone1 || t.isRetry
          ? t.choices.firstWhere((c) => c.value == t.expectedChoiceValue)
          : t.choices.firstWhere((c) => c.value != t.expectedChoiceValue);
      reviewSession.submitChoice(chosen);
      reviewSession.advanceAfterFeedback();
    }
    expect(reviewSession.outcome!.isDailyReview, isTrue);
    await progressRepo.applyReviewOutcomes(reviewSession.buildUpdatedReviewItems());

    // Advance 1 day -> only lapsed tone:4 is due; tone:1 is at 3d (+2 more days).
    currentNow = currentNow.add(const Duration(days: 1));
    final dueAfter1d = await progressRepo.loadDueReviewItems();
    expect(dueAfter1d.map((r) => r.skillId), ['u1_l1_high_vs_low:tone:4']);
    expect(dueAfter1d.first.lapses, 1);

    // Replaying u1_l1 later must NOT reset tone:1's interval via INSERT OR IGNORE.
    await progressRepo.completeLessonAttempt(
      lessonId: spec1.id,
      accuracy: 0.70,
      passed: false,
      nextLessonId: 'u1_l2_rising_2',
      skillsToSeed: spec1.seedSkills,
    );
    prog = await progressRepo.loadAllLessonProgress();
    expect(prog[spec1.id]?.status, LessonStatus.completed);
    expect(prog[spec1.id]?.bestAccuracy, 0.875);

    await progressRepo.completeLessonAttempt(
      lessonId: spec1.id,
      accuracy: 1.0,
      passed: true,
      nextLessonId: 'u1_l2_rising_2',
      skillsToSeed: spec1.seedSkills,
    );
    currentNow = currentNow.add(const Duration(days: 2)); // 3 days since tone:1 passed
    final dueAt3d = await progressRepo.loadDueReviewItems();
    expect(dueAt3d.any((r) => r.skillId == 'u1_l1_high_vs_low:tone:1' && r.intervalStage == 1), isTrue);
  });

  test('Unit 7 u7_l1 statsComponents excludes locked Vowel & Ending slots', () async {
    final catalog = _testCatalog();
    final spec71 = Curriculum.lessonById('u7_l1_start_plus_tone')!;
    final session = LessonSession.startLesson(
      spec71,
      catalog: catalog,
      random: Random(5),
      scheduler: ReviewScheduler(clock: () => currentNow),
    );
    final t = session.currentTrial!;
    expect(
      t.statsComponents,
      equals([ComponentType.initial, ComponentType.tone]),
    );
    session.submitAssembly(
      DraftInputState(
        initial: t.target.initial,
        nucleus: t.target.nucleus,
        coda: t.target.coda,
        tone: t.target.tone,
      ),
    );
    await statsRepo.recordAttemptBatch(session.pendingStats);
    final allStats = await statsRepo.loadAllStats();
    expect(
      allStats.every(
        (s) =>
            s.component == ComponentType.initial ||
            s.component == ComponentType.tone,
      ),
      isTrue,
    );
  });
}
