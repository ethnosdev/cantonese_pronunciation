import 'package:material_ui/material_ui.dart';

import '../audio/audio_playback_service.dart';
import '../data/audio_bundle_repository.dart';
import '../data/stats_repository.dart';
import '../data/syllable_repository.dart';
import '../state/bundle_controller.dart';
import '../state/quiz_controller.dart';
import 'quiz_screen.dart';
import 'settings_credits_screen.dart';
import 'soundboard_screen.dart';
import 'stats_screen.dart';

/// Top-level shell initializing QuizController and routing secondary screens.
class QuizShellScreen extends StatefulWidget {
  const QuizShellScreen({
    super.key,
    required this.quizController,
    required this.bundleController,
    required this.syllableRepository,
    required this.statsRepository,
    required this.bundleRepository,
    required this.audioService,
  });

  final QuizController quizController;
  final BundleController bundleController;
  final SyllableRepository syllableRepository;
  final StatsRepository statsRepository;
  final AudioBundleRepository bundleRepository;
  final AudioPlaybackService audioService;

  @override
  State<QuizShellScreen> createState() => _QuizShellScreenState();
}

class _QuizShellScreenState extends State<QuizShellScreen> {
  @override
  void initState() {
    super.initState();
    widget.quizController.initialize();
  }

  void _openSoundboard() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SoundboardScreen(
          syllableRepository: widget.syllableRepository,
          bundleRepository: widget.bundleRepository,
          audioService: widget.audioService,
          initialTier: widget.quizController.settings.tier,
        ),
      ),
    );
  }

  void _openStats() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatsScreen(statsRepository: widget.statsRepository),
      ),
    );
  }

  void _openSettingsCredits() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsCreditsScreen(
          bundleController: widget.bundleController,
          quizController: widget.quizController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return QuizScreen(
      controller: widget.quizController,
      onOpenSoundboard: _openSoundboard,
      onOpenStats: _openStats,
      onOpenSettings: _openSettingsCredits,
    );
  }
}
