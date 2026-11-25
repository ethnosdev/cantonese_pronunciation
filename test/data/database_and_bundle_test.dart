import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cantonese_pronunciation/core/curriculum.dart';
import 'package:cantonese_pronunciation/core/lesson_spec.dart';
import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:cantonese_pronunciation/data/audio_bundle_repository.dart';
import 'package:cantonese_pronunciation/data/database_helper.dart';
import 'package:cantonese_pronunciation/data/progress_repository.dart';
import 'package:cantonese_pronunciation/data/stats_repository.dart';
import 'package:cantonese_pronunciation/data/syllable_repository.dart';
import 'package:cantonese_pronunciation/state/bundle_controller.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

List<int> _buildTestZip({
  required List<Map<String, Object?>> syllables,
  List<ArchiveFile> extraFiles = const [],
}) {
  final archive = Archive();
  final catalogBytes = utf8.encode(
    jsonEncode({
      'version': 1,
      'speaker': 'kt',
      'format': 'opus',
      'syllables': syllables,
    }),
  );
  archive.addFile(
    ArchiveFile('syllables.json', catalogBytes.length, catalogBytes),
  );
  for (final s in syllables) {
    final path = s['path'] as String;
    final audio = utf8.encode('OggS-test-$path');
    archive.addFile(ArchiveFile(path, audio.length, audio));
  }
  for (final f in extraFiles) {
    archive.addFile(f);
  }
  return ZipEncoder().encode(archive);
}

void main() {
  sqfliteFfiInit();

  late Directory rootDir;
  late Directory supportDir;
  late Directory tempDir;
  late DatabaseHelper dbHelper;
  late SyllableRepository syllableRepo;
  late StatsRepository statsRepo;
  final excludedPaths = <String>[];

  final sampleEntries = [
    {
      'syllable': 'aa1',
      'path': 'aa/1/aa1.opus',
      'initial': '',
      'nucleus': 'aa',
      'coda': '',
      'tone': 1,
      'initialGroup': 0,
      'priority': 0,
    },
    {
      'syllable': 'm4',
      'path': 'm/4/m4.opus',
      'initial': '',
      'nucleus': '',
      'coda': 'm',
      'tone': 4,
      'initialGroup': 0,
      'priority': 0,
    },
  ];

  setUp(() async {
    rootDir = await Directory.systemTemp.createTemp('cantonese_test_');
    supportDir = Directory(p.join(rootDir.path, 'support'))..createSync();
    tempDir = Directory(p.join(rootDir.path, 'temp'))..createSync();
    excludedPaths.clear();
    dbHelper = DatabaseHelper(
      factory: databaseFactoryFfi,
      supportDirProvider: () async => supportDir,
    );
    syllableRepo = SyllableRepository(dbHelper);
    statsRepo = StatsRepository(dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
    if (rootDir.existsSync()) {
      await rootDir.delete(recursive: true);
    }
  });

  test('installs valid zip, verifies offline with zero HTTP calls, and preserves stats on repair', () async {
    final zipBytes = _buildTestZip(syllables: sampleEntries);
    final sha = sha256.convert(zipBytes).toString();

    var httpCalls = 0;
    final client = MockClient((request) async {
      httpCalls++;
      return http.Response.bytes(zipBytes, 200);
    });

    final repo = AudioBundleRepository(
      syllableRepository: syllableRepo,
      databaseHelper: dbHelper,
      httpClient: client,
      supportDirProvider: () async => supportDir,
      tempDirProvider: () async => tempDir,
      excludeFromBackup: (path) async => excludedPaths.add(path),
      freeSpaceProvider: (_) async => 200 * 1024 * 1024,
      bundleUrl: 'https://example.r2.dev/test.zip',
      expectedByteSize: zipBytes.length,
      expectedSha256: sha,
      expectedFileCount: 2,
    );

    expect(await repo.isBundleReady(), isFalse);
    await repo.installOrRepair(onProgress: (_, _) {});
    expect(httpCalls, 1);
    expect(await repo.isBundleReady(), isTrue);
    expect(excludedPaths.length, 2);

    // Offline readiness check makes zero HTTP requests.
    expect(await repo.isBundleReady(), isTrue);
    expect(httpCalls, 1);

    // Record stats + settings, then repair and verify stats remain intact.
    await statsRepo.recordAttempt(
      GradingResult(
        target: SyllableEntry.fromDbRow({
          'syllable': 'aa1',
          'path': 'aa/1/aa1.opus',
          'initial': '',
          'nucleus': 'aa',
          'coda': '',
          'tone': 1,
          'initial_group': 0,
          'priority': 0,
        }),
        guessedKey: const SyllableKey(
          initial: '',
          nucleus: 'aa',
          coda: '',
          tone: 3,
        ),
        guessedEntry: null,
        grades: const {
          ComponentType.tone: ComponentGrade(
            component: ComponentType.tone,
            expected: '1',
            guessed: '3',
            isCorrect: false,
          ),
        },
        statsComponents: const [ComponentType.tone],
        autoNormalizedSyllabicNasal: false,
        toneFamily: const [],
      ),
    );
    await statsRepo.saveSettings(
      const AppSettings(constraintMode: ConstraintMode.guided),
    );

    await repo.installOrRepair(onProgress: (_, _) {});
    expect(httpCalls, 2);
    expect((await statsRepo.loadTopConfusions()).first.count, 1);
    expect(
      (await statsRepo.loadSettings()).constraintMode,
      ConstraintMode.guided,
    );
  });

  test('rejects SHA-256 mismatch, Zip-Slip path escape, and keeps prior bundle on repair failure', () async {
    final goodZip = _buildTestZip(syllables: sampleEntries);
    final goodSha = sha256.convert(goodZip).toString();

    var serveBad = false;
    final badHashRepo = AudioBundleRepository(
      syllableRepository: syllableRepo,
      databaseHelper: dbHelper,
      httpClient: MockClient((_) async {
        if (serveBad) return http.Response('Network error', 500);
        return http.Response.bytes(goodZip, 200);
      }),
      supportDirProvider: () async => supportDir,
      tempDirProvider: () async => tempDir,
      excludeFromBackup: (_) async {},
      freeSpaceProvider: (_) async => 200 * 1024 * 1024,
      bundleUrl: 'https://example.r2.dev/test.zip',
      expectedByteSize: goodZip.length,
      expectedSha256: goodSha,
      expectedFileCount: 2,
    );

    final controller = BundleController(badHashRepo);
    await controller.checkInitialStatus();
    expect(controller.status, BundleStatus.missing);

    await controller.installOrRepair();
    expect(controller.hasUsableBundle, isTrue);
    expect(controller.status, BundleStatus.ready);

    // Non-blocking repair failure leaves hasUsableBundle true.
    serveBad = true;
    await controller.installOrRepair();
    expect(controller.hasUsableBundle, isTrue);
    expect(controller.repairError, isNotNull);

    // Zip-Slip path traversal rejection.
    final evilEntry = ArchiveFile('../evil.txt', 4, utf8.encode('pwn!'));
    final evilZip = _buildTestZip(
      syllables: sampleEntries,
      extraFiles: [evilEntry],
    );
    final evilRepo = AudioBundleRepository(
      syllableRepository: syllableRepo,
      databaseHelper: dbHelper,
      httpClient: MockClient((_) async => http.Response.bytes(evilZip, 200)),
      supportDirProvider: () async => supportDir,
      tempDirProvider: () async => tempDir,
      excludeFromBackup: (_) async {},
      freeSpaceProvider: (_) async => 200 * 1024 * 1024,
      bundleUrl: 'https://example.r2.dev/evil.zip',
      expectedByteSize: evilZip.length,
      expectedSha256: sha256.convert(evilZip).toString(),
      expectedFileCount: 2,
    );

    await expectLater(
      () => evilRepo.installOrRepair(onProgress: (_, _) {}),
      throwsA(isA<FormatException>()),
    );
  });

  test('installs real workspace kt_audio_opus_v1.zip end-to-end', () async {
    final realZip = File('../jyutnet-audio-bundle/dist/kt_audio_opus_v1.zip');
    if (!realZip.existsSync()) return;
    final bytes = await realZip.readAsBytes();
    final repo = AudioBundleRepository(
      syllableRepository: syllableRepo,
      databaseHelper: dbHelper,
      httpClient: MockClient((_) async => http.Response.bytes(bytes, 200)),
      supportDirProvider: () async => supportDir,
      tempDirProvider: () async => tempDir,
      excludeFromBackup: (_) async {},
      freeSpaceProvider: (_) async => 200 * 1024 * 1024,
    );

    await repo.installOrRepair(onProgress: (_, _) {});
    expect(await repo.isBundleReady(), isTrue);
    expect(await syllableRepo.countSyllables(), 5358);
  });

  test('schema v1 creates progress/review tables and isolates ThemeMode from AppSettings', () async {
    final fixedNow = DateTime.utc(2026, 11, 25, 12);
    final progressRepo = ProgressRepository(dbHelper, clock: () => fixedNow);

    await progressRepo.ensureLesson1Unlocked();
    final progress = await progressRepo.loadAllLessonProgress();
    expect(progress['u1_l1_high_vs_low']?.status, LessonStatus.unlocked);
    expect(progress['u1_l1_high_vs_low']?.updatedAt, fixedNow);

    // Save dark theme, then save Sandbox AppSettings without clobbering theme.
    await statsRepo.saveThemeMode(ThemeMode.dark);
    await statsRepo.saveSettings(
      const AppSettings(
        tier: DatasetTier.pri0And1,
        constraintMode: ConstraintMode.guided,
        focusFilter: TonesOnlyFilter(),
        autoPlay: false,
      ),
    );
    expect(await statsRepo.loadThemeMode(), ThemeMode.dark);
    expect(await statsRepo.loadAutoPlay(), isFalse);

    // Reset clears review items and re-unlocks Lesson 1.1 cleanly.
    await progressRepo.completeLessonAttempt(
      lessonId: 'u1_l1_high_vs_low',
      accuracy: 1.0,
      passed: true,
      nextLessonId: 'u1_l2_rising_2',
      skillsToSeed: Curriculum.lessonById('u1_l1_high_vs_low')!.seedSkills,
      completedAt: fixedNow,
    );
    expect(await progressRepo.countCompletedLessons(), 1);
    await progressRepo.resetLearningProgress(fixedNow.add(const Duration(hours: 1)));
    expect(await progressRepo.countCompletedLessons(), 0);
    expect(
      (await progressRepo.loadAllLessonProgress())['u1_l1_high_vs_low']?.status,
      LessonStatus.unlocked,
    );
  });
}
