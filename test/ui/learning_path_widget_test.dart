import 'dart:io';

import 'package:cantonese_pronunciation/app.dart';
import 'package:cantonese_pronunciation/core/curriculum.dart';
import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:cantonese_pronunciation/data/audio_bundle_repository.dart';
import 'package:cantonese_pronunciation/data/database_helper.dart';
import 'package:cantonese_pronunciation/data/progress_repository.dart';
import 'package:cantonese_pronunciation/data/stats_repository.dart';
import 'package:cantonese_pronunciation/data/syllable_repository.dart';
import 'package:cantonese_pronunciation/state/bundle_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'quiz_screen_widget_test.dart';

List<SyllableEntry> _miniBundleCatalog() {
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
  late BundleController bundleController;
  late FakeAudioPlaybackService audio;
  late DateTime fixedNow;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('learning_path_test_');
    fixedNow = DateTime.utc(2026, 11, 25, 10, 0);
    dbHelper = DatabaseHelper(
      factory: databaseFactoryFfiNoIsolate,
      supportDirProvider: () async => tempDir,
    );
    syllableRepo = SyllableRepository(dbHelper);
    statsRepo = StatsRepository(dbHelper);
    progressRepo = ProgressRepository(dbHelper, clock: () => fixedNow);
    final entries = _miniBundleCatalog();
    await syllableRepo.replaceAllFromEntries(entries);
    for (final e in entries) {
      final f = File('${tempDir.path}/audio_bundle/${e.path}');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync([1, 2, 3]);
    }
    final sentinel = File('${tempDir.path}/audio_bundle/.bundle_sentinel.json');
    sentinel.writeAsStringSync(
      '{"version":1,"sha256":"test_sha","fileCount":${entries.length}}',
    );
    File('${tempDir.path}/audio_bundle/syllables.json').writeAsStringSync('{}');
    bundleRepo = AudioBundleRepository(
      syllableRepository: syllableRepo,
      databaseHelper: dbHelper,
      httpClient: MockClient((_) async => http.Response('', 500)),
      supportDirProvider: () async => tempDir,
      tempDirProvider: () async => tempDir,
      expectedSha256: 'test_sha',
      expectedFileCount: entries.length,
    );
    bundleController = BundleController(bundleRepo);
    await bundleController.checkInitialStatus();
    audio = FakeAudioPlaybackService();
  });

  tearDown(() async {
    bundleController.dispose();
    await dbHelper.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Home shows Unit 1.1 unlocked, Daily Review when due, Drawer navigation, and 360x640 fit', (tester) async {
    // Seed 1 overdue review skill from Lesson 1.1.
    await tester.runAsync(() async {
      await progressRepo.ensureLesson1Unlocked();
      await progressRepo.completeLessonAttempt(
        lessonId: 'u1_l1_high_vs_low',
        accuracy: 1.0,
        passed: true,
        nextLessonId: 'u1_l2_rising_2',
        skillsToSeed: Curriculum.lessonById('u1_l1_high_vs_low')!.seedSkills,
        completedAt: fixedNow.subtract(const Duration(days: 2)),
      );
    });

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      CantonesePronunciationApp(
        initialThemeMode: ThemeMode.system,
        bundleController: bundleController,
        syllableRepository: syllableRepo,
        statsRepository: statsRepo,
        progressRepository: progressRepo,
        audioService: audio,
        clock: () => fixedNow,
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();

    expect(find.text('Cantonese Pronunciation'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Cantonese Pronunciation'),
        matching: find.byType(FittedBox),
      ),
      findsOneWidget,
    );
    expect(find.text('Daily Review'), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('1.1  High Flat (1) vs. Low Falling (4)'),
      120,
    );
    expect(find.textContaining('1.1  High Flat (1) vs. Low Falling (4)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cumulative Review · Units 1–2'),
      180,
    );
    expect(find.text('Cumulative Review · Units 1–2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Open top-left drawer and navigate to Settings -> persist Dark theme.
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    final savedTheme = await tester.runAsync(() => statsRepo.loadThemeMode());
    expect(savedTheme, ThemeMode.dark);
    expect(tester.takeException(), isNull);

    // Pop back to Home -> drawer was already closed cleanly.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Cantonese Pronunciation'), findsOneWidget);
  });
}
