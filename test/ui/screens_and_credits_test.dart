import 'dart:io';

import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:cantonese_pronunciation/data/audio_bundle_repository.dart';
import 'package:cantonese_pronunciation/data/database_helper.dart';
import 'package:cantonese_pronunciation/data/progress_repository.dart';
import 'package:cantonese_pronunciation/data/stats_repository.dart';
import 'package:cantonese_pronunciation/data/syllable_repository.dart';
import 'package:cantonese_pronunciation/state/bundle_controller.dart';
import 'package:cantonese_pronunciation/ui/about_credits_screen.dart';
import 'package:cantonese_pronunciation/ui/app_settings_screen.dart';
import 'package:cantonese_pronunciation/ui/soundboard_screen.dart';
import 'package:cantonese_pronunciation/ui/stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'quiz_screen_widget_test.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper dbHelper;
  late SyllableRepository syllableRepo;
  late StatsRepository statsRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('screens_test_');
    dbHelper = DatabaseHelper(
      factory: databaseFactoryFfiNoIsolate,
      supportDirProvider: () async => tempDir,
    );
    syllableRepo = SyllableRepository(dbHelper);
    statsRepo = StatsRepository(dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'AboutCreditsScreen renders attribution and opens external links',
    (tester) async {
      final bundleRepo = AudioBundleRepository(
        syllableRepository: syllableRepo,
        databaseHelper: dbHelper,
        httpClient: MockClient((_) async => http.Response('', 500)),
        supportDirProvider: () async => tempDir,
        tempDirProvider: () async => tempDir,
      );
      final controller = BundleController(bundleRepo);
      final launchedUrls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: AboutCreditsScreen(
            bundleController: controller,
            launchUrlFn: (uri) async {
              launchedUrls.add(uri.toString());
              return true;
            },
          ),
        ),
      );

      expect(find.textContaining('粵音資料集叢'), findsOneWidget);
      expect(find.textContaining('CC0 1.0'), findsOneWidget);

      await tester.tap(find.text('CC BY-SA 4.0'));
      await tester.pump();
      expect(
        launchedUrls,
        contains('https://creativecommons.org/licenses/by-sa/4.0/'),
      );

      await tester.tap(find.text('jyut.net'));
      await tester.pump();
      expect(launchedUrls, contains('https://jyut.net/'));
    },
  );

  testWidgets(
    'AppSettingsScreen persists ThemeMode, Auto-play, and resets progress',
    (tester) async {
      final bundleRepo = AudioBundleRepository(
        syllableRepository: syllableRepo,
        databaseHelper: dbHelper,
        httpClient: MockClient((_) async => http.Response('', 500)),
        supportDirProvider: () async => tempDir,
        tempDirProvider: () async => tempDir,
      );
      final bundleController = BundleController(bundleRepo);
      final progressRepo = ProgressRepository(dbHelper);
      await tester.runAsync(() => progressRepo.ensureLesson1Unlocked());
      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
      var resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppSettingsScreen(
            statsRepository: statsRepo,
            themeNotifier: themeNotifier,
            bundleController: bundleController,
            progressRepository: progressRepo,
            onProgressReset: () => resetCalled = true,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(themeNotifier.value, ThemeMode.dark);
      final savedTheme = await tester.runAsync(() => statsRepo.loadThemeMode());
      expect(savedTheme, ThemeMode.dark);

      await tester.tap(find.text('Reset Learning Progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(resetCalled, isTrue);
    },
  );

  testWidgets(
    'SoundboardScreen plays syllables and StatsScreen resets counts',
    (tester) async {
      const aa1 = SyllableEntry(
        syllable: 'aa1',
        path: 'aa/1/aa1.opus',
        initial: '',
        nucleus: 'aa',
        coda: '',
        tone: 1,
        initialGroup: 0,
        priority: 0,
      );
      final bundleDir = Directory('${tempDir.path}/audio_bundle/aa/1')
        ..createSync(recursive: true);
      File('${bundleDir.path}/aa1.opus').writeAsBytesSync([1, 2, 3]);
      await tester.runAsync(
        () => syllableRepo.replaceAllFromEntries(const [aa1]),
      );

      final bundleRepo = AudioBundleRepository(
        syllableRepository: syllableRepo,
        databaseHelper: dbHelper,
        httpClient: MockClient((_) async => http.Response('', 500)),
        supportDirProvider: () async => tempDir,
        tempDirProvider: () async => tempDir,
      );
      final audio = FakeAudioPlaybackService();

      await tester.pumpWidget(
        MaterialApp(
          home: SoundboardScreen(
            syllableRepository: syllableRepo,
            bundleRepository: bundleRepo,
            audioService: audio,
            initialTier: DatasetTier.pri0,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(find.textContaining('∅ = no initial.'), findsOneWidget);
      expect(find.bySemanticsLabel('No initial'), findsOneWidget);
      await tester.tap(find.text('1'));
      await tester.pump();
      expect(audio.playedPaths.last, endsWith('aa/1/aa1.opus'));

      await tester.runAsync(() async {
        final db = await dbHelper.open();
        await db.insert('confusion_stats', {
          'component': ComponentType.initial.name,
          'expected': '',
          'guessed': '',
          'count': 1234,
        });
        await statsRepo.recordAttempt(
          const GradingResult(
            target: aa1,
            guessedKey: SyllableKey(
              initial: 'ng',
              nucleus: 'aa',
              coda: '',
              tone: 3,
            ),
            guessedEntry: null,
            grades: {
              ComponentType.initial: ComponentGrade(
                component: ComponentType.initial,
                expected: '',
                guessed: 'ng',
                isCorrect: false,
              ),
              ComponentType.tone: ComponentGrade(
                component: ComponentType.tone,
                expected: '1',
                guessed: '3',
                isCorrect: false,
              ),
            },
            statsComponents: [ComponentType.initial, ComponentType.tone],
            autoNormalizedSyllabicNasal: false,
            toneFamily: [aa1],
          ),
        );
      });

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(home: StatsScreen(statsRepository: statsRepo)),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('Initial consonant'), findsOneWidget);
      expect(find.text('Vowel'), findsOneWidget);
      expect(find.text('Coda'), findsOneWidget);
      expect(find.text('Tone'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(find.text('Ending'), findsNothing);
      expect(find.text('∅'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Tone: 1 ↔ 3'), 120);
      expect(find.text('Initial: None ↔ ng'), findsOneWidget);
      expect(find.text('Tone: 1 ↔ 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Reset Stats'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('No confusions recorded yet.'), findsOneWidget);
    },
  );
}
