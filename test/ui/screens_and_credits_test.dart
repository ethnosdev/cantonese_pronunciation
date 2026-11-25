import 'dart:io';

import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:cantonese_pronunciation/data/audio_bundle_repository.dart';
import 'package:cantonese_pronunciation/data/database_helper.dart';
import 'package:cantonese_pronunciation/data/stats_repository.dart';
import 'package:cantonese_pronunciation/data/syllable_repository.dart';
import 'package:cantonese_pronunciation/state/bundle_controller.dart';
import 'package:cantonese_pronunciation/ui/bundle_setup_screen.dart';
import 'package:cantonese_pronunciation/ui/settings_credits_screen.dart';
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

  testWidgets('BundleSetupScreen shows ~19.2 MB prompt, offline error, and Credits link', (tester) async {
    final bundleRepo = AudioBundleRepository(
      syllableRepository: syllableRepo,
      databaseHelper: dbHelper,
      httpClient: MockClient((_) async => http.Response('Offline', 503)),
      supportDirProvider: () async => tempDir,
      tempDirProvider: () async => tempDir,
      freeSpaceProvider: (_) async => 200 * 1024 * 1024,
    );
    final controller = BundleController(bundleRepo);
    await controller.checkInitialStatus();

    var creditsTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: BundleSetupScreen(
          bundleController: controller,
          onOpenCredits: () => creditsTapped = true,
        ),
      ),
    );

    expect(find.textContaining('19.2 MB'), findsWidgets);
    expect(find.text('Download Audio Pack (~19.2 MB)'), findsOneWidget);

    await tester.tap(find.text('Credits'));
    expect(creditsTapped, isTrue);

    await tester.tap(find.text('Download Audio Pack (~19.2 MB)'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('Retry Download (~19.2 MB)'), findsOneWidget);
  });

  testWidgets('SettingsCreditsScreen renders attribution and opens external links', (tester) async {
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
        home: SettingsCreditsScreen(
          bundleController: controller,
          quizController: null,
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
    expect(launchedUrls, contains('https://creativecommons.org/licenses/by-sa/4.0/'));

    await tester.tap(find.text('jyut.net'));
    await tester.pump();
    expect(launchedUrls, contains('https://jyut.net/'));
  });

  testWidgets('SoundboardScreen plays syllables and StatsScreen resets counts', (tester) async {
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
    await tester.runAsync(() => syllableRepo.replaceAllFromEntries(const [aa1]));

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
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    await tester.tap(find.text('1'));
    await tester.pump();
    expect(audio.playedPaths.last, endsWith('aa/1/aa1.opus'));

    await tester.runAsync(
      () => statsRepo.recordAttempt(
        const GradingResult(
          target: aa1,
          guessedKey: SyllableKey(initial: '', nucleus: 'aa', coda: '', tone: 3),
          guessedEntry: null,
          grades: {
            ComponentType.tone: ComponentGrade(
              component: ComponentType.tone,
              expected: '1',
              guessed: '3',
              isCorrect: false,
            ),
          },
          statsComponents: [ComponentType.tone],
          autoNormalizedSyllabicNasal: false,
          toneFamily: [aa1],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: StatsScreen(statsRepository: statsRepo)),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(find.text('Tone: 1 ↔ 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Reset Stats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('No confusions recorded yet.'), findsOneWidget);
  });
}
