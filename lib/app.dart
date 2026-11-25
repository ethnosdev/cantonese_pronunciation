import 'package:material_ui/material_ui.dart';

import 'audio/audio_playback_service.dart';
import 'audio/soloud_audio_service.dart';
import 'data/audio_bundle_repository.dart';
import 'data/database_helper.dart';
import 'data/stats_repository.dart';
import 'data/syllable_repository.dart';
import 'state/bundle_controller.dart';
import 'state/quiz_controller.dart';
import 'ui/bundle_setup_screen.dart';
import 'ui/quiz_shell_screen.dart';
import 'ui/settings_credits_screen.dart';

/// Root Flutter widget composing dependencies and routing between Setup & Quiz.
class CantonesePronunciationApp extends StatefulWidget {
  const CantonesePronunciationApp({
    super.key,
    this.bundleController,
    this.quizController,
    this.syllableRepository,
    this.statsRepository,
    this.audioService,
  });

  final BundleController? bundleController;
  final QuizController? quizController;
  final SyllableRepository? syllableRepository;
  final StatsRepository? statsRepository;
  final AudioPlaybackService? audioService;

  @override
  State<CantonesePronunciationApp> createState() =>
      _CantonesePronunciationAppState();
}

class _CantonesePronunciationAppState extends State<CantonesePronunciationApp> {
  late final DatabaseHelper _dbHelper;
  late final SyllableRepository _syllableRepo;
  late final StatsRepository _statsRepo;
  late final AudioBundleRepository _bundleRepo;
  late final AudioPlaybackService _audioService;
  late final BundleController _bundleController;
  late final QuizController _quizController;
  bool _ownsDependencies = false;

  @override
  void initState() {
    super.initState();
    if (widget.bundleController != null &&
        widget.quizController != null &&
        widget.syllableRepository != null &&
        widget.statsRepository != null &&
        widget.audioService != null) {
      _syllableRepo = widget.syllableRepository!;
      _statsRepo = widget.statsRepository!;
      _audioService = widget.audioService!;
      _bundleController = widget.bundleController!;
      _bundleRepo = _bundleController.repository;
      _quizController = widget.quizController!;
    } else {
      _ownsDependencies = true;
      _dbHelper = DatabaseHelper();
      _syllableRepo = SyllableRepository(_dbHelper);
      _statsRepo = StatsRepository(_dbHelper);
      _bundleRepo = AudioBundleRepository(
        syllableRepository: _syllableRepo,
        databaseHelper: _dbHelper,
      );
      _audioService = SoLoudAudioService();
      _bundleController = BundleController(_bundleRepo);
      _audioService.onPlaybackError = (_, error) {
        _bundleController.markCorrupted('Audio playback failed: $error');
      };
      _quizController = QuizController(
        syllableRepository: _syllableRepo,
        statsRepository: _statsRepo,
        bundleRepository: _bundleRepo,
        audioService: _audioService,
      );
      _bundleController.checkInitialStatus();
    }
  }

  @override
  void dispose() {
    if (_ownsDependencies) {
      _audioService.dispose();
      _dbHelper.close();
      _bundleController.dispose();
      _quizController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cantonese Pronunciation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F766E),
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: _bundleController,
        builder: (context, _) {
          if (_bundleController.hasUsableBundle) {
            return QuizShellScreen(
              quizController: _quizController,
              bundleController: _bundleController,
              syllableRepository: _syllableRepo,
              statsRepository: _statsRepo,
              bundleRepository: _bundleRepo,
              audioService: _audioService,
            );
          }
          return BundleSetupScreen(
            bundleController: _bundleController,
            onOpenCredits: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsCreditsScreen(
                    bundleController: _bundleController,
                    quizController: null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
