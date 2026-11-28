import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cantonese_pronunciation/core/curriculum.dart';
import 'package:cantonese_pronunciation/core/lesson_spec.dart';
import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:cantonese_pronunciation/data/audio_bundle_repository.dart';
import 'package:cantonese_pronunciation/data/database_helper.dart';
import 'package:cantonese_pronunciation/data/progress_repository.dart';
import 'package:cantonese_pronunciation/data/stats_repository.dart';
import 'package:cantonese_pronunciation/data/syllable_repository.dart';
import 'package:cantonese_pronunciation/state/lesson_session_controller.dart';
import 'package:cantonese_pronunciation/ui/lesson_screen.dart';
import 'package:cantonese_pronunciation/ui/widgets/feedback_tone_wheel_panel.dart';
import 'package:cantonese_pronunciation/ui/widgets/pitch_contour_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'quiz_screen_widget_test.dart';

List<SyllableEntry> _lessonCatalog() {
  final list = <SyllableEntry>[];
  for (final i in const ['b', 'p', 'd', 's', '']) {
    for (final t in const [1, 2, 3, 4, 5, 6]) {
      final syl = '${i}aa$t';
      list.add(
        SyllableEntry(
          syllable: syl,
          path: 'aa/$t/$syl.opus',
          initial: i,
          nucleus: 'aa',
          coda: '',
          tone: t,
          initialGroup: 0,
          priority: 0,
        ),
      );
    }
  }
  return list;
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper dbHelper;
  late SyllableRepository syllableRepo;
  late StatsRepository statsRepo;
  late ProgressRepository progressRepo;
  late AudioBundleRepository bundleRepo;
  late FakeAudioPlaybackService audio;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lesson_screen_test_');
    dbHelper = DatabaseHelper(
      factory: databaseFactoryFfiNoIsolate,
      supportDirProvider: () async => tempDir,
    );
    syllableRepo = SyllableRepository(dbHelper);
    statsRepo = StatsRepository(dbHelper);
    progressRepo = ProgressRepository(dbHelper);
    final entries = _lessonCatalog();
    await syllableRepo.replaceAllFromEntries(entries);
    for (final e in entries) {
      final f = File('${tempDir.path}/audio_bundle/${e.path}');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync([1, 2, 3]);
    }
    bundleRepo = AudioBundleRepository(
      syllableRepository: syllableRepo,
      databaseHelper: dbHelper,
      httpClient: MockClient((_) async => http.Response('', 500)),
      supportDirProvider: () async => tempDir,
      tempDirProvider: () async => tempDir,
    );
    audio = FakeAudioPlaybackService();
  });

  tearDown(() async {
    await dbHelper.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<LessonSessionController> pumpLesson(
    WidgetTester tester,
    LessonSpec spec, {
    bool autoPlay = true,
  }) async {
    await tester.runAsync(() => statsRepo.saveAutoPlay(autoPlay));
    final ctrl = LessonSessionController(
      syllableRepository: syllableRepo,
      bundleRepository: bundleRepo,
      statsRepository: statsRepo,
      progressRepository: progressRepo,
      audioService: audio,
      lessonSpec: spec,
      random: Random(1),
    );
    await tester.runAsync(() => ctrl.initialize());

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: LessonScreen(
          controller: ctrl,
          onRetryLesson: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ctrl;
  }

  testWidgets('1.1 Hear-and-Compare, Same/Diff autoPlay=false guard, contour buttons, and close guard', (tester) async {
    final spec11 = Curriculum.lessonById('u1_l1_high_vs_low')!;
    final ctrl = await pumpLesson(tester, spec11, autoPlay: false);
    addTearDown(ctrl.dispose);

    // Intro visible, Trial 1 has NOT auto-played.
    expect(find.text('Start Practice'), findsOneWidget);
    expect(find.text('1 · High Level'), findsOneWidget);
    expect(find.byType(PitchContourBox), findsNWidgets(2));
    expect(audio.playedPaths, isEmpty);
    expect(tester.takeException(), isNull);

    // Advance to Warmup Same/Diff; buttons remain disabled until Play Pair.
    await tester.ensureVisible(find.text('Start Practice'));
    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();
    expect(find.text('Same tone?'), findsOneWidget);
    expect(ctrl.canSubmitSameDifferent, isFalse);

    await tester.ensureVisible(find.text('Play Pair'));
    await tester.tap(find.text('Play Pair'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(ctrl.canSubmitSameDifferent, isTrue);
    expect(audio.playedPaths.length, 2);

    // Complete both Same/Diff warmups cleanly.
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Same'));
      await tester.tap(find.text('Same'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      if (i == 0 && !ctrl.canSubmitSameDifferent) {
        await tester.ensureVisible(find.text('Play Pair'));
        await tester.tap(find.text('Play Pair'));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pumpAndSettle();
      }
    }

    // Core choice cards: curves visible, NO Chao digits '55'/'21'.
    expect(find.text('High Level'), findsOneWidget);
    expect(find.text('55'), findsNothing);
    expect(find.byType(PitchContourBox), findsNWidgets(2));

    // Close before submitting any graded item pops without dialog.
    await tester.tap(find.text('High Level'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(ctrl.submittedCount, 1);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Lesson?'), findsOneWidget);
  });

  testWidgets('u3_l4 hides contours on 6 choices, fits 360x640, and shows curves in feedback', (tester) async {
    final spec34 = Curriculum.lessonById('u3_l4_six_tone_check')!;
    final ctrl = await pumpLesson(tester, spec34);
    addTearDown(ctrl.dispose);

    // 6 choices rendered with curves OFF on buttons and uniform button height.
    expect(find.text('High Level'), findsOneWidget);
    expect(find.text('Low Level'), findsOneWidget);
    expect(find.byType(PitchContourBox), findsNothing);
    expect(tester.takeException(), isNull);

    final choiceHeights = [
      for (final label in const [
        'High Level',
        'High Rising',
        'Mid Level',
        'Low Falling',
        'Low Rising',
        'Low Level',
      ])
        tester.getSize(find.ancestor(of: find.text(label), matching: find.byType(Material)).first).height,
    ];
    expect(choiceHeights.toSet().length, 1);

    await tester.tap(find.text('High Level'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();

    // Feedback shows curve(s), whole-card audio tap works, and Next has no overflow.
    expect(find.text('Next'), findsOneWidget);
    expect(find.byType(PitchContourBox), findsWidgets);
    expect(tester.takeException(), isNull);

    final playsBeforeTap = audio.playedPaths.length;
    await tester.ensureVisible(find.textContaining('Target · '));
    await tester.tap(find.textContaining('Target · '));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(audio.playedPaths.length, greaterThan(playsBeforeTap));
  });

  testWidgets('Unit 7 u7_l1, u7_l2, and u7_l4 migrate to 3-step keyboard and 3-badge FeedbackToneWheelPanel', (tester) async {
    final spec71 = Curriculum.lessonById('u7_l1_start_plus_tone')!;
    final ctrl71 = await pumpLesson(tester, spec71);
    addTearDown(ctrl71.dispose);

    expect(find.text('Build the initial consonant and tone.'), findsOneWidget);
    expect(find.text('Initial consonant'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Submit'), findsNothing);
    expect(tester.takeException(), isNull);

    // Tapping None renders '∅' on practice-slot-start and advances to Tone, remaining tappable.
    await tester.ensureVisible(find.text('None'));
    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    expect(find.text('Tone'), findsOneWidget);
    expect(find.byKey(const ValueKey('practice-slot-start')), findsOneWidget);
    expect(find.text('∅'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('practice-slot-start')));
    await tester.pumpAndSettle();
    expect(find.text('Initial consonant'), findsOneWidget);

    await tester.tap(find.text('b').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('High Level'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackToneWheelPanel), findsOneWidget);
    expect(find.textContaining('Initial:'), findsOneWidget);
    expect(find.textContaining('Final:'), findsOneWidget);
    expect(find.textContaining('Tone:'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final spec72 = Curriculum.lessonById('u7_l2_vowel_ending_tone')!;
    final ctrl72 = await pumpLesson(tester, spec72);
    addTearDown(ctrl72.dispose);
    expect(find.text('Build the final and tone.'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    await tester.tap(find.text('aa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High Level'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackToneWheelPanel), findsOneWidget);
    expect(tester.takeException(), isNull);

    final spec74 = Curriculum.lessonById('u7_l4_open_42_keys')!;
    final ctrl74 = await pumpLesson(tester, spec74);
    addTearDown(ctrl74.dispose);

    expect(find.text('Build the full syllable.'), findsOneWidget);
    await tester.ensureVisible(find.text('b'));
    await tester.tap(find.text('b'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('aa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High Level'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackToneWheelPanel), findsOneWidget);
    expect(find.textContaining('Initial:'), findsOneWidget);
    expect(find.textContaining('Final:'), findsOneWidget);
    expect(find.textContaining('Tone:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('highlights Target and Your Guess cards in sync with comparison audio playback', (tester) async {
    final ctrlAudio = _ControllableAudioService();
    await tester.runAsync(() => statsRepo.saveAutoPlay(false));
    final spec34 = Curriculum.lessonById('u3_l4_six_tone_check')!;
    final ctrl = LessonSessionController(
      syllableRepository: syllableRepo,
      bundleRepository: bundleRepo,
      statsRepository: statsRepo,
      progressRepository: progressRepo,
      audioService: ctrlAudio,
      lessonSpec: spec34,
      random: Random(1),
    );
    addTearDown(ctrl.dispose);

    await tester.runAsync(() => ctrl.initialize());
    await tester.pumpWidget(
      MaterialApp(
        home: LessonScreen(controller: ctrl, onRetryLesson: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final wrongChoice = ctrl.currentTrial!.choices.firstWhere(
      (c) => c.value != ctrl.currentTrial!.expectedChoiceValue,
    );
    final wrongTapLabel = wrongChoice.tone != null
        ? Curriculum.tonePlainNames[wrongChoice.tone!]!
        : wrongChoice.label;
    await tester.tap(find.text(wrongTapLabel));
    await tester.pump();
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && ctrlAudio.clipDone == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pump();

    double opacityFor(String prefix) {
      final finder = find.ancestor(
        of: find.textContaining(prefix),
        matching: find.byType(AnimatedOpacity),
      );
      return tester.widget<AnimatedOpacity>(finder.first).opacity;
    }

    double borderWidthFor(String prefix) {
      final finder = find.ancestor(
        of: find.textContaining(prefix),
        matching: find.byType(AnimatedContainer),
      );
      final dec =
          tester.widget<AnimatedContainer>(finder.first).decoration!
              as BoxDecoration;
      return dec.border!.top.width;
    }

    // Clip 0 (Target) playing -> Target bright/2.5px border, Guess dimmed.
    expect(ctrl.activeFeedbackClipIndex, 0);
    expect(opacityFor('Target · '), 1.0);
    expect(borderWidthFor('Target · '), 2.5);
    expect(opacityFor('Your Guess · '), 0.52);
    expect(borderWidthFor('Your Guess · '), 1.0);

    // End Clip 0 -> inter-clip pause: neither card highlighted or dimmed.
    final c0 = ctrlAudio.clipDone!;
    ctrlAudio.clipDone = null;
    c0.complete();
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && ctrlAudio.gapDone == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();
    expect(ctrl.activeFeedbackClipIndex, isNull);
    expect(opacityFor('Target · '), 1.0);
    expect(opacityFor('Your Guess · '), 1.0);
    expect(borderWidthFor('Target · '), 1.0);

    // End pause -> Clip 1 (Your Guess) playing -> Guess 2.5px border, Target dimmed.
    final g0 = ctrlAudio.gapDone!;
    ctrlAudio.gapDone = null;
    g0.complete();
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && ctrlAudio.clipDone == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();
    expect(ctrl.activeFeedbackClipIndex, 1);
    expect(opacityFor('Your Guess · '), 1.0);
    expect(borderWidthFor('Your Guess · '), 2.5);
    expect(opacityFor('Target · '), 0.52);

    // End Clip 1 -> both return to normal.
    final c1 = ctrlAudio.clipDone!;
    ctrlAudio.clipDone = null;
    c1.complete();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
    expect(ctrl.activeFeedbackClipIndex, isNull);
    expect(opacityFor('Target · '), 1.0);
    expect(opacityFor('Your Guess · '), 1.0);

    // Manual tap on Target highlights Target while playing and clears on end.
    await tester.ensureVisible(find.textContaining('Target · '));
    await tester.tap(find.textContaining('Target · '));
    await tester.pump();
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && ctrlAudio.clipDone == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();
    expect(ctrl.activeFeedbackClipIndex, 0);
    expect(borderWidthFor('Target · '), 2.5);
    expect(opacityFor('Your Guess · '), 0.52);

    final cManual = ctrlAudio.clipDone!;
    ctrlAudio.clipDone = null;
    cManual.complete();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
    expect(ctrl.activeFeedbackClipIndex, isNull);
    expect(opacityFor('Your Guess · '), 1.0);
  });

  testWidgets('Phonetics & IPA starts collapsed, expands on tap with sticky Start Practice, and Lesson notes opens mid-lesson', (tester) async {
    final spec21 = Curriculum.lessonById('u2_l1_b_vs_p')!;
    final ctrl = await pumpLesson(tester, spec21, autoPlay: true);
    addTearDown(ctrl.dispose);

    // HearAndCompareView: sticky CTA visible immediately at 360x640 (1.3x), Phonetics & IPA collapsed.
    expect(find.text('Phonetics & IPA'), findsOneWidget);
    expect(find.textContaining('IPA [pʰ]'), findsNothing);
    expect(find.text('Start Practice'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Start Practice')).dy,
      lessThanOrEqualTo(640),
    );
    expect(find.byTooltip('Lesson notes'), findsNothing);
    expect(tester.takeException(), isNull);

    // Expanding Phonetics & IPA reveals tagged IPA while Start Practice stays pinned in footer.
    await tester.tap(find.text('Phonetics & IPA'));
    await tester.pumpAndSettle();
    expect(find.textContaining('IPA [pʰ]'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Start Practice')).dy,
      lessThanOrEqualTo(640),
    );
    expect(tester.takeException(), isNull);

    // Advance to Warmup -> info_outline ('Lesson notes') stops audio and opens modal sheet without resetting state.
    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();
    expect(ctrl.phase, SessionPhase.warmup);
    expect(find.byTooltip('Lesson notes'), findsOneWidget);

    final stopsBeforeSheet = audio.stopCalls;
    await tester.tap(find.byTooltip('Lesson notes'));
    await tester.pumpAndSettle();
    expect(audio.stopCalls, greaterThan(stopsBeforeSheet));
    expect(find.text('Lesson 2.1 · b vs. p'), findsOneWidget);
    expect(find.text(spec21.introSummary), findsOneWidget);
    expect(find.textContaining('IPA [pʰ]'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Close notes'));
    await tester.pumpAndSettle();
    expect(ctrl.phase, SessionPhase.warmup);
    expect(find.text('Same initial consonant?'), findsOneWidget);
  });
}

class _ControllableAudioService extends FakeAudioPlaybackService {
  Completer<void>? clipDone;
  Completer<void>? gapDone;

  @override
  Future<void> playSequence(
    List<String> paths, {
    Duration initialDelay = Duration.zero,
    Duration gap = const Duration(milliseconds: 450),
    void Function(int index)? onClipStart,
    void Function(int index)? onClipEnd,
  }) async {
    for (var i = 0; i < paths.length; i++) {
      onClipStart?.call(i);
      playedPaths.add(paths[i]);
      clipDone = Completer<void>();
      await clipDone!.future;
      onClipEnd?.call(i);
      if (i + 1 < paths.length && gap > Duration.zero) {
        gapDone = Completer<void>();
        await gapDone!.future;
      }
    }
  }
}
