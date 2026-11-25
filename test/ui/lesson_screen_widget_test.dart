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
  for (final i in const ['b', 'd', 's']) {
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
    expect(find.text('1 · High Flat'), findsOneWidget);
    expect(find.byType(PitchContourBox), findsNWidgets(2));
    expect(audio.playedPaths, isEmpty);
    expect(tester.takeException(), isNull);

    // Advance to Warmup Same/Diff; buttons remain disabled until Play Pair.
    await tester.ensureVisible(find.text('Start Practice'));
    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();
    expect(find.text('Same Tone?'), findsOneWidget);
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
    expect(find.text('1 · High Flat'), findsOneWidget);
    expect(find.text('55'), findsNothing);
    expect(find.byType(PitchContourBox), findsNWidgets(2));

    // Close before submitting any graded item pops without dialog.
    await tester.tap(find.text('1 · High Flat'));
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

    // 6 choices rendered with curves OFF on buttons.
    expect(find.text('1 · High Flat'), findsOneWidget);
    expect(find.text('6 · Low Flat'), findsOneWidget);
    expect(find.byType(PitchContourBox), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('1 · High Flat'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();

    // Feedback shows curve(s) and Next without overflow.
    expect(find.text('Next'), findsOneWidget);
    expect(find.byType(PitchContourBox), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unit 7 u7_l1 renders None for locked open ending and u7_l4 uses FeedbackToneWheelPanel', (tester) async {
    final spec71 = Curriculum.lessonById('u7_l1_start_plus_tone')!;
    final ctrl71 = await pumpLesson(tester, spec71);
    addTearDown(ctrl71.dispose);

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('None'), findsOneWidget); // open coda '' locked displays 'None'
    expect(find.text('Submit'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final spec74 = Curriculum.lessonById('u7_l4_open_42_keys')!;
    final ctrl74 = await pumpLesson(tester, spec74);
    addTearDown(ctrl74.dispose);

    await tester.ensureVisible(find.text('b'));
    await tester.tap(find.text('b'));
    await tester.ensureVisible(find.text('aa'));
    await tester.tap(find.text('aa'));
    await tester.ensureVisible(find.text('1').first);
    await tester.tap(find.text('1').first);
    await tester.pump();
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackToneWheelPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
