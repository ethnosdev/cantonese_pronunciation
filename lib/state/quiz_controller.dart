import 'package:flutter/foundation.dart';

import '../audio/audio_playback_service.dart';
import '../core/guided_constraint_engine.dart';
import '../core/syllable_grader.dart';
import '../core/syllable_models.dart';
import '../core/weighted_sampler.dart';
import '../data/audio_bundle_repository.dart';
import '../data/stats_repository.dart';
import '../data/syllable_repository.dart';

export '../core/syllable_models.dart' show PracticeStep;

/// Coordinates Practice turns, 3-step keyboard flow, Guided/Test constraints, and grading.
class QuizController extends ChangeNotifier {
  QuizController({
    required SyllableRepository syllableRepository,
    required StatsRepository statsRepository,
    required AudioBundleRepository bundleRepository,
    required this.audioService,
    WeightedSampler? sampler,
  }) : _syllableRepo = syllableRepository,
       _statsRepo = statsRepository,
       _bundleRepo = bundleRepository,
       _sampler = sampler ?? WeightedSampler();

  final SyllableRepository _syllableRepo;
  final StatsRepository _statsRepo;
  final AudioBundleRepository _bundleRepo;
  final AudioPlaybackService audioService;
  final WeightedSampler _sampler;

  AppSettings _settings = const AppSettings();
  List<SyllableEntry> _allCatalog = const [];
  Map<SyllableKey, SyllableEntry> _catalogByKey = const {};
  List<SyllableEntry> _activePool = const [];
  GuidedConstraintEngine _constraintEngine = GuidedConstraintEngine(const []);
  List<ConfusionStat> _cachedStats = const [];

  SyllableEntry? _currentTarget;
  DraftInputState _draft = const DraftInputState();
  PracticeStep _activeStep = PracticeStep.initial;
  GradingResult? _lastResult;
  bool _isLoading = true;
  String? _audioError;
  int? _activeFeedbackClipIndex;
  int _playbackToken = 0;

  AppSettings get settings => _settings;
  List<SyllableEntry> get activePool => _activePool;
  SyllableEntry? get currentTarget => _currentTarget;
  DraftInputState get draft => _draft;
  PracticeStep get activeStep => _activeStep;
  GradingResult? get lastResult => _lastResult;
  bool get isLoading => _isLoading;
  String? get audioError => _audioError;
  int? get activeFeedbackClipIndex => _activeFeedbackClipIndex;
  bool get isSubmitted => _lastResult != null;
  bool get isTonesOnlyLocked => _settings.focusFilter is TonesOnlyFilter;
  Set<PracticeStep> get lockedSteps => isTonesOnlyLocked
      ? const {PracticeStep.initial, PracticeStep.syllableFinal}
      : const {};
  String? get selectedEnding =>
      ThreeStepAssemblyHelper.selectedEndingFor(_draft);

  bool get canSubmit {
    if (isSubmitted || _currentTarget == null) return false;
    return ThreeStepAssemblyHelper.canSubmitAssembly(
      draft: _draft,
      engine: _constraintEngine,
      filter: _settings.focusFilter,
      lockedSteps: lockedSteps,
      isGuided: _settings.constraintMode == ConstraintMode.guided,
      preventToneLeaking: true,
    );
  }

  /// Enabled Initial values (`''` for None, `'b'`, `'gw'`, etc.) in Guided mode.
  Set<String> allowedStarts() {
    if (_settings.constraintMode == ConstraintMode.test) {
      return const {};
    }
    return _constraintEngine.allowedStarts();
  }

  /// Enabled 57-Final strings in Guided mode given the selected Initial.
  Set<String> allowedEndings() {
    if (_settings.constraintMode == ConstraintMode.test) {
      return const {};
    }
    return _constraintEngine.allowedEndings(_draft.initial);
  }

  Set<int> allowedTones() {
    if (_settings.constraintMode == ConstraintMode.test) {
      return const {1, 2, 3, 4, 5, 6};
    }
    return _constraintEngine.allowedTones(
      _draft,
      _settings.focusFilter,
      preventToneLeaking: true,
    );
  }

  Future<void> initialize() async {
    _isLoading = true;
    _audioError = null;
    notifyListeners();

    _settings = await _statsRepo.loadSettings();
    _allCatalog = await _syllableRepo.loadAll();
    _catalogByKey = {for (final e in _allCatalog) e.key: e};
    _cachedStats = await _statsRepo.loadAllStats();
    await _reloadPoolAndStartTurn(playAudio: _settings.autoPlay);
  }

  Future<void> updateSettings(AppSettings updated) async {
    final poolChanged =
        updated.tier != _settings.tier ||
        updated.focusFilter != _settings.focusFilter;
    _settings = updated;
    await _statsRepo.saveSettings(updated);
    if (poolChanged) {
      await _reloadPoolAndStartTurn(playAudio: _settings.autoPlay);
    } else {
      notifyListeners();
    }
  }

  void setActiveStep(PracticeStep step) {
    if (isSubmitted || lockedSteps.contains(step)) return;
    _activeStep = step;
    notifyListeners();
  }

  /// Picks Initial (`''` for None) and advances automatically to Final (or Tone if Final is set).
  void selectStart(String initial) {
    if (isSubmitted || lockedSteps.contains(PracticeStep.initial)) return;
    final transition = ThreeStepAssemblyHelper.selectStart(
      draft: _draft,
      currentStep: _activeStep,
      initial: initial,
      engine: _constraintEngine,
      lockedSteps: lockedSteps,
      isGuided: _settings.constraintMode == ConstraintMode.guided,
    );
    _draft = transition.draft;
    _activeStep = transition.nextStep;
    notifyListeners();
  }

  /// Picks one of the 57 Finals and advances to Tone (or Initial if Initial is unselected).
  void selectEnding(String finalStr) {
    if (isSubmitted || lockedSteps.contains(PracticeStep.syllableFinal)) return;
    final transition = ThreeStepAssemblyHelper.selectEnding(
      draft: _draft,
      currentStep: _activeStep,
      finalStr: finalStr,
      lockedSteps: lockedSteps,
    );
    _draft = transition.draft;
    _activeStep = transition.nextStep;
    notifyListeners();
  }

  /// Picks Tone and submits when Initial and Final (or syllabic nasal alias) are filled.
  Future<void> selectToneAndSubmit(int tone) async {
    if (isSubmitted) return;
    final transition = ThreeStepAssemblyHelper.selectToneAndSubmit(
      draft: _draft,
      currentStep: _activeStep,
      tone: tone,
      engine: _constraintEngine,
      filter: _settings.focusFilter,
      lockedSteps: lockedSteps,
      isGuided: _settings.constraintMode == ConstraintMode.guided,
      preventToneLeaking: true,
    );
    _draft = transition.draft;
    _activeStep = transition.nextStep;
    if (transition.shouldSubmit) {
      await submit();
    } else {
      notifyListeners();
    }
  }

  void clearAll() {
    if (isSubmitted) return;
    if (isTonesOnlyLocked) {
      _draft = _draft.copyWith(tone: null);
      _activeStep = PracticeStep.tone;
    } else {
      _draft = const DraftInputState();
      _activeStep = PracticeStep.initial;
    }
    notifyListeners();
  }

  Future<void> submit() async {
    final target = _currentTarget;
    if (!canSubmit || target == null) return;

    final result = SyllableGrader.grade(
      target: target,
      draft: _draft,
      filter: _settings.focusFilter,
      lookupEntry: (key) => _catalogByKey[key],
      lookupToneFamily: (i, n, c) => _allCatalog
          .where((e) => e.initial == i && e.nucleus == n && e.coda == c)
          .toList()
        ..sort((a, b) => a.tone.compareTo(b.tone)),
    );

    _lastResult = result;
    notifyListeners();

    await _statsRepo.recordAttempt(result);
    _cachedStats = await _statsRepo.loadAllStats();
  }

  Future<void> nextTurn() async {
    await audioService.clearTurnSources();
    _startTurn(playAudio: _settings.autoPlay);
  }

  Future<void> playTarget() async {
    final target = _currentTarget;
    if (target == null) return;
    if (isSubmitted) {
      await _playComparisonClip(target, 0);
    } else {
      await _playEntry(target);
    }
  }

  Future<void> playGuess() async {
    final guess = _lastResult?.guessedEntry;
    if (guess == null) return;
    await _playComparisonClip(guess, 1);
  }

  Future<void> playEntry(SyllableEntry entry) async {
    await _playEntry(entry);
  }

  Future<void> handleEnterKey() async {
    if (isSubmitted) {
      await nextTurn();
    } else if (canSubmit) {
      await submit();
    }
  }

  Future<void> _reloadPoolAndStartTurn({required bool playAudio}) async {
    _isLoading = true;
    notifyListeners();

    final tierPool = await _syllableRepo.loadPool(_settings.tier);
    _constraintEngine = GuidedConstraintEngine(tierPool);

    if (_settings.focusFilter is AllFilter ||
        _settings.focusFilter is TonesOnlyFilter) {
      _activePool = tierPool;
    } else {
      _activePool = tierPool.where(_settings.focusFilter.matches).toList();
    }

    _isLoading = false;
    await audioService.clearTurnSources();
    _startTurn(playAudio: playAudio);
  }

  void _startTurn({required bool playAudio}) {
    _playbackToken++;
    _activeFeedbackClipIndex = null;
    _lastResult = null;
    _audioError = null;
    if (_activePool.isEmpty) {
      _currentTarget = null;
      _draft = const DraftInputState();
      notifyListeners();
      return;
    }

    final next = _sampler.pickNext(
      pool: _activePool,
      stats: _cachedStats,
      previousSyllable: _currentTarget?.syllable,
    );
    _currentTarget = next;

    if (_settings.focusFilter is TonesOnlyFilter) {
      _draft = DraftInputState(
        initial: next.initial,
        nucleus: next.nucleus,
        coda: next.coda,
        tone: null,
      );
      _activeStep = PracticeStep.tone;
    } else {
      _draft = const DraftInputState();
      _activeStep = PracticeStep.initial;
    }

    notifyListeners();
    if (playAudio) {
      // Trigger playback asynchronously without blocking frame update.
      Future<void>.microtask(() => _playEntry(next));
    }
  }

  Future<void> _playComparisonClip(SyllableEntry entry, int clipIndex) async {
    final myToken = ++_playbackToken;
    try {
      _audioError = null;
      final fullPath = await _bundleRepo.resolveAudioFilePath(entry.path);
      await audioService.playSequence(
        [fullPath],
        onClipStart: (_) {
          if (myToken != _playbackToken) return;
          _activeFeedbackClipIndex = clipIndex;
          notifyListeners();
        },
        onClipEnd: (_) {
          if (myToken != _playbackToken) return;
          _activeFeedbackClipIndex = null;
          notifyListeners();
        },
      );
    } catch (e) {
      _audioError = e.toString();
      notifyListeners();
    } finally {
      if (myToken == _playbackToken && _activeFeedbackClipIndex != null) {
        _activeFeedbackClipIndex = null;
        notifyListeners();
      }
    }
  }

  Future<void> _playEntry(SyllableEntry entry) async {
    _playbackToken++;
    if (_activeFeedbackClipIndex != null) {
      _activeFeedbackClipIndex = null;
      notifyListeners();
    }
    try {
      _audioError = null;
      final fullPath = await _bundleRepo.resolveAudioFilePath(entry.path);
      await audioService.playFile(fullPath);
    } catch (e) {
      _audioError = e.toString();
      notifyListeners();
    }
  }
}
