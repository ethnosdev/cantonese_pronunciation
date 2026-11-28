import 'dart:io';
import 'dart:math';

import 'package:cantonese_pronunciation/audio/audio_playback_service.dart';
import 'package:cantonese_pronunciation/core/curriculum.dart';
import 'package:cantonese_pronunciation/core/lesson_session.dart';
import 'package:cantonese_pronunciation/core/lesson_spec.dart';
import 'package:cantonese_pronunciation/core/review_scheduler.dart';
import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:cantonese_pronunciation/data/audio_bundle_repository.dart';
import 'package:cantonese_pronunciation/data/database_helper.dart';
import 'package:cantonese_pronunciation/data/progress_repository.dart';
import 'package:cantonese_pronunciation/data/stats_repository.dart';
import 'package:cantonese_pronunciation/data/syllable_repository.dart';
import 'package:cantonese_pronunciation/state/lesson_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _SilentAudioService implements AudioPlaybackService {
  @override
  void Function(String path, Object error)? onPlaybackError;

  @override
  Future<void> clearTurnSources() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> init() async {}

  @override
  Future<void> playFile(String absolutePath) async {}

  @override
  Future<void> playSequence(
    List<String> paths, {
    Duration initialDelay = Duration.zero,
    Duration gap = const Duration(milliseconds: 450),
    void Function(int index)? onClipStart,
    void Function(int index)? onClipEnd,
  }) async {}

  @override
  Future<void> stop() async {}
}

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

  test('Cumulative unit reviews split 50/50 latest/earlier, bias to confusions, and unlock safely on upgrade', () async {
    final catalog = <SyllableEntry>[
      ..._testCatalog(),
      for (final i in const ['p', 't', 'g', 'k'])
        for (final t in const [1, 2, 3, 4])
          SyllableEntry(
            syllable: '${i}aa$t',
            path: 'aa/$t/${i}aa$t.opus',
            initial: i,
            nucleus: 'aa',
            coda: '',
            tone: t,
            initialGroup: 0,
            priority: 0,
          ),
    ];

    final u2Review = Curriculum.lessonById('u2_review')!;
    final reviewSession = LessonSession.startLesson(
      u2Review,
      catalog: catalog,
      confusionStats: const [
        ConfusionStat(
          component: ComponentType.initial,
          expected: 'g',
          guessed: 'k',
          count: 40,
        ),
      ],
      random: Random(9),
      scheduler: ReviewScheduler(clock: () => currentNow),
    );
    expect(reviewSession.phase, SessionPhase.trial);
    expect(reviewSession.hearAndCompareCards, isEmpty);
    expect(reviewSession.warmupTrials, isEmpty);
    expect(reviewSession.gradedTotal, 20);

    var u1Count = 0;
    var u2Count = 0;
    var gTargetCount = 0;
    while (reviewSession.phase == SessionPhase.trial) {
      final t = reviewSession.currentTrial!;
      expect(t.showContoursOnButtons, isFalse);
      if (t.sourceLessonId.startsWith('u1_')) u1Count++;
      if (t.sourceLessonId.startsWith('u2_')) u2Count++;
      if (t.expectedChoiceValue == 'g') gTargetCount++;
      reviewSession.submitChoice(
        t.choices.firstWhere((c) => c.value == t.expectedChoiceValue),
      );
      reviewSession.advanceAfterFeedback();
    }
    expect(u1Count, 10);
    expect(u2Count, 10);
    expect(gTargetCount, greaterThan(0));
    expect(reviewSession.outcome!.passed, isTrue);

    // Passing u2_l4 unlocks u2_review, and passing u2_review unlocks u3_l1.
    await progressRepo.completeLessonAttempt(
      lessonId: 'u2_l4_stops_review',
      accuracy: 0.9,
      passed: true,
      nextLessonId: Curriculum.nextLessonIdAfter('u2_l4_stops_review'),
      skillsToSeed: const [],
    );
    var prog = await progressRepo.loadAllLessonProgress();
    expect(prog['u2_review']?.status, LessonStatus.unlocked);

    await progressRepo.completeLessonAttempt(
      lessonId: 'u2_review',
      accuracy: 0.9,
      passed: true,
      nextLessonId: Curriculum.nextLessonIdAfter('u2_review'),
      skillsToSeed: const [],
    );
    prog = await progressRepo.loadAllLessonProgress();
    expect(prog['u2_review']?.status, LessonStatus.completed);
    expect(prog['u3_l1_rising_2_vs_5']?.status, LessonStatus.unlocked);

    // Upgrade safety: existing DB with u3_l1 unlocked before u2_review existed auto-unlocks u2_review.
    final upgradeDir = await Directory.systemTemp.createTemp('upgrade_test_');
    try {
      final upgradeDb = DatabaseHelper(
        factory: databaseFactoryFfiNoIsolate,
        supportDirProvider: () async => upgradeDir,
      );
      final upgradeRepo = ProgressRepository(upgradeDb, clock: () => currentNow);
      final db = await upgradeDb.open();
      await db.insert('lesson_progress', {
        'lesson_id': 'u3_l1_rising_2_vs_5',
        'status': LessonStatus.unlocked.name,
        'best_accuracy': 0.0,
        'attempts_count': 0,
        'last_completed_at': null,
        'updated_at': currentNow.millisecondsSinceEpoch,
      });
      await upgradeRepo.ensureLesson1Unlocked();
      final upgraded = await upgradeRepo.loadAllLessonProgress();
      expect(upgraded['u2_review']?.status, LessonStatus.unlocked);
      await upgradeDb.close();
    } finally {
      if (upgradeDir.existsSync()) {
        await upgradeDir.delete(recursive: true);
      }
    }
  });

  test('LessonSessionController enforces 3-step locked slots and 7.4 unguided rules', () async {
    final syllableRepo = SyllableRepository(dbHelper);
    await syllableRepo.replaceAllFromEntries(_testCatalog());
    final bundleRepo = AudioBundleRepository(
      syllableRepository: syllableRepo,
      databaseHelper: dbHelper,
      httpClient: MockClient((_) async => http.Response('', 500)),
      supportDirProvider: () async => tempDir,
      tempDirProvider: () async => tempDir,
    );
    await statsRepo.saveAutoPlay(false);

    // 7.1: syllableFinal locked, starts on Initial, blocks blank initial, guards Final taps.
    final ctrl71 = LessonSessionController(
      syllableRepository: syllableRepo,
      bundleRepository: bundleRepo,
      statsRepository: statsRepo,
      progressRepository: progressRepo,
      audioService: _SilentAudioService(),
      lessonSpec: Curriculum.lessonById('u7_l1_start_plus_tone'),
      random: Random(1),
    );
    await ctrl71.initialize();
    expect(ctrl71.lockedSteps, {PracticeStep.syllableFinal});
    expect(ctrl71.activeStep, PracticeStep.initial);
    expect(ctrl71.canSubmitAssembly, isFalse);
    await ctrl71.selectToneAndSubmit(1);
    expect(ctrl71.phase, SessionPhase.trial);
    expect(ctrl71.draft.tone, isNull);
    final lockedEnding = ctrl71.selectedEnding;
    ctrl71.selectEnding('eoi');
    expect(ctrl71.selectedEnding, lockedEnding);
    ctrl71.selectStart(ctrl71.currentTrial!.target.initial);
    expect(ctrl71.activeStep, PracticeStep.tone);
    ctrl71.dispose();

    // 7.2: initial locked, starts on syllableFinal.
    final ctrl72 = LessonSessionController(
      syllableRepository: syllableRepo,
      bundleRepository: bundleRepo,
      statsRepository: statsRepo,
      progressRepository: progressRepo,
      audioService: _SilentAudioService(),
      lessonSpec: Curriculum.lessonById('u7_l2_vowel_ending_tone'),
      random: Random(2),
    );
    await ctrl72.initialize();
    expect(ctrl72.lockedSteps, {PracticeStep.initial});
    expect(ctrl72.activeStep, PracticeStep.syllableFinal);
    ctrl72.dispose();

    // 7.3: Guided full syllable keeps open initials while preventing checked-tone leaking.
    final ctrl73 = LessonSessionController(
      syllableRepository: syllableRepo,
      bundleRepository: bundleRepo,
      statsRepository: statsRepo,
      progressRepository: progressRepo,
      audioService: _SilentAudioService(),
      lessonSpec: Curriculum.lessonById('u7_l3_guided_42_keys'),
      random: Random(3),
    );
    await ctrl73.initialize();
    expect(ctrl73.lockedSteps, isEmpty);
    ctrl73.selectStart('b');
    ctrl73.selectEnding('aak');
    expect(ctrl73.allowedTones(), {1, 2, 3, 4, 5, 6});
    ctrl73.dispose();

    // 7.4: Unguided keeps allowedStarts/Endings empty and allows all 6 tones.
    final ctrl74 = LessonSessionController(
      syllableRepository: syllableRepo,
      bundleRepository: bundleRepo,
      statsRepository: statsRepo,
      progressRepository: progressRepo,
      audioService: _SilentAudioService(),
      lessonSpec: Curriculum.lessonById('u7_l4_open_42_keys'),
      random: Random(4),
    );
    await ctrl74.initialize();
    expect(ctrl74.allowedStarts(), isEmpty);
    expect(ctrl74.allowedEndings(), isEmpty);
    expect(ctrl74.allowedTones(), {1, 2, 3, 4, 5, 6});
    ctrl74.dispose();
  });
}
