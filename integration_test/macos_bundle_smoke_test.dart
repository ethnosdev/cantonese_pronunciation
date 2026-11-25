import 'package:cantonese_pronunciation/audio/soloud_audio_service.dart';
import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:cantonese_pronunciation/data/audio_bundle_repository.dart';
import 'package:cantonese_pronunciation/data/database_helper.dart';
import 'package:cantonese_pronunciation/data/syllable_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('downloads, verifies, extracts, imports, and plays real opus on macOS', (tester) async {
    final dbHelper = DatabaseHelper();
    final syllableRepo = SyllableRepository(dbHelper);
    final bundleRepo = AudioBundleRepository(
      syllableRepository: syllableRepo,
      databaseHelper: dbHelper,
    );

    await bundleRepo.installOrRepair(onProgress: (_, _) {});
    expect(await bundleRepo.isBundleReady(), isTrue);
    expect(await syllableRepo.countSyllables(), 5358);

    final pool = await syllableRepo.loadPool(DatasetTier.pri0);
    expect(pool.length, 2520);

    final audio = SoLoudAudioService();
    await audio.init();
    final path = await bundleRepo.resolveAudioFilePath(pool.first.path);
    await audio.playFile(path);
    await audio.clearTurnSources();
    await audio.dispose();
    await dbHelper.close();
  });
}
