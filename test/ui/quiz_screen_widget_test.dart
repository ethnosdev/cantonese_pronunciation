import 'dart:io';

import 'package:cantonese_pronunciation/audio/audio_playback_service.dart';
import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:cantonese_pronunciation/core/weighted_sampler.dart';
import 'package:cantonese_pronunciation/data/audio_bundle_repository.dart';
import 'package:cantonese_pronunciation/data/database_helper.dart';
import 'package:cantonese_pronunciation/data/stats_repository.dart';
import 'package:cantonese_pronunciation/data/syllable_repository.dart';
import 'package:cantonese_pronunciation/state/quiz_controller.dart';
import 'package:cantonese_pronunciation/ui/quiz_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeAudioPlaybackService implements AudioPlaybackService {
  final List<String> playedPaths = [];
  int clearTurnCalls = 0;
  int stopCalls = 0;

  @override
  void Function(String path, Object error)? onPlaybackError;

  @override
  Future<void> init() async {}

  @override
  Future<void> playFile(String absolutePath) async {
    playedPaths.add(absolutePath);
  }

  @override
  Future<void> playSequence(
    List<String> paths, {
    Duration initialDelay = Duration.zero,
    Duration gap = const Duration(milliseconds: 450),
    void Function(int index)? onClipStart,
  }) async {
    for (var i = 0; i < paths.length; i++) {
      onClipStart?.call(i);
      playedPaths.add(paths[i]);
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> clearTurnSources() async {
    clearTurnCalls++;
  }

  @override
  Future<void> dispose() async {}
}

class FixedSampler extends WeightedSampler {
  FixedSampler(this.fixedEntry);
  final SyllableEntry fixedEntry;

  @override
  SyllableEntry pickNext({
    required List<SyllableEntry> pool,
    required List<ConfusionStat> stats,
    String? previousSyllable,
  }) => fixedEntry;
}

void main() {
  sqfliteFfiInit();

  const baa1 = SyllableEntry(
    syllable: 'baa1',
    path: 'aa/1/baa1.opus',
    initial: 'b',
    nucleus: 'aa',
    coda: '',
    tone: 1,
    initialGroup: 1,
    priority: 0,
  );
  const baa2 = SyllableEntry(
    syllable: 'baa2',
    path: 'aa/2/baa2.opus',
    initial: 'b',
    nucleus: 'aa',
    coda: '',
    tone: 2,
    initialGroup: 1,
    priority: 1,
  );

  late Directory tempDir;
  late DatabaseHelper dbHelper;
  late SyllableRepository syllableRepo;
  late StatsRepository statsRepo;
  late AudioBundleRepository bundleRepo;
  late FakeAudioPlaybackService audio;
  late QuizController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quiz_widget_');
    final bundleDir = Directory('${tempDir.path}/audio_bundle')..createSync();
    Directory('${bundleDir.path}/aa/1').createSync(recursive: true);
    Directory('${bundleDir.path}/aa/2').createSync(recursive: true);
    File('${bundleDir.path}/aa/1/baa1.opus').writeAsBytesSync([1, 2, 3]);
    File('${bundleDir.path}/aa/2/baa2.opus').writeAsBytesSync([1, 2, 3]);

    dbHelper = DatabaseHelper(
      factory: databaseFactoryFfiNoIsolate,
      supportDirProvider: () async => tempDir,
    );
    syllableRepo = SyllableRepository(dbHelper);
    statsRepo = StatsRepository(dbHelper);
    await syllableRepo.replaceAllFromEntries(const [baa1, baa2]);

    bundleRepo = AudioBundleRepository(
      syllableRepository: syllableRepo,
      databaseHelper: dbHelper,
      httpClient: MockClient((_) async => http.Response('', 500)),
      supportDirProvider: () async => tempDir,
      tempDirProvider: () async => tempDir,
    );
    audio = FakeAudioPlaybackService();
    controller = QuizController(
      syllableRepository: syllableRepo,
      statsRepository: statsRepo,
      bundleRepository: bundleRepo,
      audioService: audio,
      sampler: FixedSampler(baa1),
    );
    await controller.initialize();
  });

  tearDown(() async {
    controller.dispose();
    await dbHelper.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpQuizAtSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: QuizScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders without overflow at 360x640, 390x844, and 1024x768 pre- and post-submit', (tester) async {
    for (final size in const [
      Size(360, 640),
      Size(390, 844),
      Size(1024, 768),
    ]) {
      await pumpQuizAtSize(tester, size);
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('55'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    // Any-order entry: tap Tone 1, then Coda -k (unrecorded), then Nucleus aa, then Initial b.
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('-k'));
    await tester.pump();
    await tester.tap(find.text('aa'));
    await tester.pump();
    await tester.tap(find.text('b'));
    await tester.pump();

    // Tap -k again to toggle back to open syllable, then tap -p for unrecorded guess baap1.
    await tester.tap(find.text('-k'));
    await tester.pump();
    await tester.tap(find.text('-p'));
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();

    expect(
      find.text('This combination (baap1) does not exist in the dataset.'),
      findsOneWidget,
    );
    expect(find.text('Next'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tap Tone Wheel 2 and verify playback, then advance turn via Enter key.
    await tester.tap(find.text('2'));
    await tester.pump();
    expect(audio.playedPaths.last, endsWith('aa/2/baa2.opus'));

    final priorClears = audio.clearTurnCalls;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(audio.clearTurnCalls, greaterThan(priorClears));
    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets('supports Space replay and Escape clear shortcuts', (tester) async {
    await pumpQuizAtSize(tester, const Size(390, 844));
    final initialPlays = audio.playedPaths.length;

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(audio.playedPaths.length, greaterThan(initialPlays));

    await tester.tap(find.text('b'));
    await tester.pump();
    expect(controller.draft.initial, 'b');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.draft.initial, isNull);
  });
}
