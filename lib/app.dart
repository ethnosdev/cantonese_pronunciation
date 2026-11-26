import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'audio/audio_playback_service.dart';
import 'audio/soloud_audio_service.dart';
import 'core/lesson_spec.dart';
import 'data/audio_bundle_repository.dart';
import 'data/database_helper.dart';
import 'data/progress_repository.dart';
import 'data/stats_repository.dart';
import 'data/syllable_repository.dart';
import 'state/bundle_controller.dart';
import 'state/learning_path_controller.dart';
import 'state/lesson_session_controller.dart';
import 'state/quiz_controller.dart';
import 'ui/about_credits_screen.dart';
import 'ui/app_settings_screen.dart';
import 'ui/bundle_setup_screen.dart';
import 'ui/learning_path_home_screen.dart';
import 'ui/lesson_screen.dart';
import 'ui/quiz_screen.dart';
import 'ui/soundboard_screen.dart';
import 'ui/stats_screen.dart';

/// Root Flutter widget composing dependencies, theme, and root bundle routing.
class CantonesePronunciationApp extends StatefulWidget {
  const CantonesePronunciationApp({
    super.key,
    this.initialThemeMode = ThemeMode.system,
    this.bundleController,
    this.quizController,
    this.syllableRepository,
    this.statsRepository,
    this.progressRepository,
    this.audioService,
    this.clock,
  });

  final ThemeMode initialThemeMode;
  final BundleController? bundleController;
  final QuizController? quizController;
  final SyllableRepository? syllableRepository;
  final StatsRepository? statsRepository;
  final ProgressRepository? progressRepository;
  final AudioPlaybackService? audioService;
  final DateTime Function()? clock;

  @override
  State<CantonesePronunciationApp> createState() =>
      _CantonesePronunciationAppState();
}

class _CantonesePronunciationAppState extends State<CantonesePronunciationApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final DatabaseHelper _dbHelper;
  late final SyllableRepository _syllableRepo;
  late final StatsRepository _statsRepo;
  late final ProgressRepository _progressRepo;
  late final AudioBundleRepository _bundleRepo;
  late final AudioPlaybackService _audioService;
  late final BundleController _bundleController;
  late final LearningPathController _pathController;
  late final ValueNotifier<ThemeMode> _themeNotifier;

  QuizController? _sandboxController;
  bool _ownsDependencies = false;
  bool _ownsSandboxController = false;
  bool _lastUsableBundle = false;

  @override
  void initState() {
    super.initState();
    _themeNotifier = ValueNotifier<ThemeMode>(widget.initialThemeMode);

    if (widget.bundleController != null &&
        widget.syllableRepository != null &&
        widget.statsRepository != null &&
        widget.progressRepository != null &&
        widget.audioService != null) {
      _syllableRepo = widget.syllableRepository!;
      _statsRepo = widget.statsRepository!;
      _progressRepo = widget.progressRepository!;
      _audioService = widget.audioService!;
      _bundleController = widget.bundleController!;
      _bundleRepo = _bundleController.repository;
      _sandboxController = widget.quizController;
    } else {
      _ownsDependencies = true;
      _dbHelper = DatabaseHelper();
      _syllableRepo = SyllableRepository(_dbHelper);
      _statsRepo = StatsRepository(_dbHelper);
      _progressRepo = ProgressRepository(_dbHelper, clock: widget.clock);
      _bundleRepo = AudioBundleRepository(
        syllableRepository: _syllableRepo,
        databaseHelper: _dbHelper,
      );
      _audioService = SoLoudAudioService();
      _bundleController = BundleController(_bundleRepo);
      _audioService.onPlaybackError = (path, error) {
        if (!File(path).existsSync()) {
          _bundleController.markCorrupted('Missing audio file: $error');
        }
      };
      _sandboxController = widget.quizController;
      _bundleController.checkInitialStatus();
    }

    _pathController = LearningPathController(
      progressRepository: _progressRepo,
      clock: widget.clock,
    );
    _lastUsableBundle = _bundleController.hasUsableBundle;
    _bundleController.addListener(_onBundleStatusChanged);
    if (_lastUsableBundle) {
      unawaited(_pathController.refresh());
    }
  }

  void _onBundleStatusChanged() {
    final nowUsable = _bundleController.hasUsableBundle;
    if (nowUsable != _lastUsableBundle) {
      _lastUsableBundle = nowUsable;
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      if (nowUsable) {
        unawaited(_pathController.refresh());
      }
    }
  }

  QuizController _getOrCreateSandboxController() {
    if (_sandboxController != null) return _sandboxController!;
    _ownsSandboxController = true;
    final created = QuizController(
      syllableRepository: _syllableRepo,
      statsRepository: _statsRepo,
      bundleRepository: _bundleRepo,
      audioService: _audioService,
    );
    unawaited(created.initialize());
    _sandboxController = created;
    return created;
  }

  @override
  void dispose() {
    _bundleController.removeListener(_onBundleStatusChanged);
    _themeNotifier.dispose();
    _pathController.dispose();
    if (_ownsSandboxController) {
      _sandboxController?.dispose();
    }
    if (_ownsDependencies) {
      _audioService.dispose();
      _dbHelper.close();
      _bundleController.dispose();
    }
    super.dispose();
  }

  Future<void> _openLesson(LessonSpec? lesson) async {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    await nav.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _LessonRouteHost(
          lessonSpec: lesson,
          syllableRepository: _syllableRepo,
          bundleRepository: _bundleRepo,
          statsRepository: _statsRepo,
          progressRepository: _progressRepo,
          audioService: _audioService,
          clock: widget.clock,
          onOpenLessonReplacement: (nextLesson) {
            nav.pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => _LessonRouteHost(
                  lessonSpec: nextLesson,
                  syllableRepository: _syllableRepo,
                  bundleRepository: _bundleRepo,
                  statsRepository: _statsRepo,
                  progressRepository: _progressRepo,
                  audioService: _audioService,
                  clock: widget.clock,
                  onOpenLessonReplacement: null,
                ),
              ),
            );
          },
        ),
      ),
    );
    await _pathController.refresh();
  }

  void _pushRoute(Widget screen) {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    const seed = Color(0xFF0F766E);
    final base = ThemeData(
      colorSchemeSeed: seed,
      brightness: brightness,
      useMaterial3: true,
    );
    final text = base.textTheme;
    return base.copyWith(
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(fontSize: 26),
        titleLarge: text.titleLarge?.copyWith(fontSize: 24),
        titleMedium: text.titleMedium?.copyWith(fontSize: 18),
        titleSmall: text.titleSmall?.copyWith(fontSize: 16),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 18),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 16),
        bodySmall: text.bodySmall?.copyWith(fontSize: 14),
        labelLarge: text.labelLarge?.copyWith(fontSize: 16),
        labelMedium: text.labelMedium?.copyWith(fontSize: 14),
        labelSmall: text.labelSmall?.copyWith(fontSize: 13),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Cantonese Pronunciation',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeMode,
          home: ListenableBuilder(
            listenable: _bundleController,
            builder: (context, _) {
              if (_bundleController.hasUsableBundle) {
                return LearningPathHomeScreen(
                  controller: _pathController,
                  onStartLesson: (lesson) => _openLesson(lesson),
                  onOpenSandbox: () => _pushRoute(
                    QuizScreen(controller: _getOrCreateSandboxController()),
                  ),
                  onOpenSoundboard: () => _pushRoute(
                    SoundboardScreen(
                      syllableRepository: _syllableRepo,
                      bundleRepository: _bundleRepo,
                      audioService: _audioService,
                    ),
                  ),
                  onOpenStats: () => _pushRoute(
                    StatsScreen(statsRepository: _statsRepo),
                  ),
                  onOpenSettings: () => _pushRoute(
                    AppSettingsScreen(
                      statsRepository: _statsRepo,
                      themeNotifier: _themeNotifier,
                      bundleController: _bundleController,
                      progressRepository: _progressRepo,
                      onProgressReset: () =>
                          unawaited(_pathController.refresh()),
                    ),
                  ),
                  onOpenAbout: () => _pushRoute(
                    AboutCreditsScreen(bundleController: _bundleController),
                  ),
                );
              }
              return BundleSetupScreen(
                bundleController: _bundleController,
                onOpenCredits: () => _pushRoute(
                  AboutCreditsScreen(bundleController: _bundleController),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LessonRouteHost extends StatefulWidget {
  const _LessonRouteHost({
    required this.lessonSpec,
    required this.syllableRepository,
    required this.bundleRepository,
    required this.statsRepository,
    required this.progressRepository,
    required this.audioService,
    required this.clock,
    required this.onOpenLessonReplacement,
  });

  final LessonSpec? lessonSpec;
  final SyllableRepository syllableRepository;
  final AudioBundleRepository bundleRepository;
  final StatsRepository statsRepository;
  final ProgressRepository progressRepository;
  final AudioPlaybackService audioService;
  final DateTime Function()? clock;
  final void Function(LessonSpec? nextLesson)? onOpenLessonReplacement;

  @override
  State<_LessonRouteHost> createState() => _LessonRouteHostState();
}

class _LessonRouteHostState extends State<_LessonRouteHost> {
  late LessonSessionController _controller;

  @override
  void initState() {
    super.initState();
    _initController(widget.lessonSpec);
  }

  void _initController(LessonSpec? spec) {
    _controller = LessonSessionController(
      syllableRepository: widget.syllableRepository,
      bundleRepository: widget.bundleRepository,
      statsRepository: widget.statsRepository,
      progressRepository: widget.progressRepository,
      audioService: widget.audioService,
      lessonSpec: spec,
      clock: widget.clock,
    );
    unawaited(_controller.initialize());
  }

  void _replaceWith(LessonSpec? spec) {
    final old = _controller;
    setState(() {
      _initController(spec);
    });
    old.dispose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LessonScreen(
      controller: _controller,
      onRetryLesson: () => _replaceWith(_controller.lessonSpec),
      onOpenNextLesson: (next) => _replaceWith(next),
      onReviewMore: _controller.isDailyReview
          ? () => _replaceWith(null)
          : null,
    );
  }
}
