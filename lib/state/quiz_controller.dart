import 'package:flutter/foundation.dart';

import '../audio/audio_playback_service.dart';
import '../core/guided_constraint_engine.dart';
import '../core/jyutping_constants.dart';
import '../core/syllable_grader.dart';
import '../core/syllable_models.dart';
import '../core/weighted_sampler.dart';
import '../data/audio_bundle_repository.dart';
import '../data/stats_repository.dart';
import '../data/syllable_repository.dart';

/// Active keyboard step in the 3-step Practice word builder.
enum PracticeStep { start, ending, tone }

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
  PracticeStep _activeStep = PracticeStep.start;
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
  String? get selectedEnding =>
      _draft.nucleus == null ? null : '${_draft.nucleus}${_draft.coda ?? ''}';

  bool get canSubmit {
    if (isSubmitted || _currentTarget == null) return false;
    if (_settings.constraintMode == ConstraintMode.guided) {
      return _constraintEngine.canSubmit(
        _draft,
        _settings.focusFilter,
        preventToneLeaking: true,
      );
    }
    return _draft.canSubmit;
  }

  /// Enabled Start values (`''` for None, `'b'`, etc.) in Guided mode.
  Set<String> allowedStarts() {
    if (_settings.constraintMode == ConstraintMode.test) {
      return const {};
    }
    final ending = selectedEnding;
    return {
      for (final e in _constraintEngine.pool)
        if (ending == null || '${e.nucleus}${e.coda}' == ending) e.initial,
    };
  }

  /// Enabled 57-Final Ending strings in Guided mode given the selected Start.
  Set<String> allowedEndings() {
    if (_settings.constraintMode == ConstraintMode.test) {
      return const {};
    }
    return {
      for (final e in _constraintEngine.pool)
        if (_draft.initial == null || e.initial == _draft.initial)
          '${e.nucleus}${e.coda}',
    };
  }

  Set<String> allowedInitials() {
    if (_settings.constraintMode == ConstraintMode.test) {
      return const {};
    }
    return _constraintEngine.allowedInitials(_draft);
  }

  Set<String> allowedNuclei() {
    if (_settings.constraintMode == ConstraintMode.test) {
      return const {};
    }
    return _constraintEngine.allowedNuclei(_draft);
  }

  Set<String> allowedCodas() {
    if (_settings.constraintMode == ConstraintMode.test) {
      return const {};
    }
    return _constraintEngine.allowedCodas(_draft);
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
    if (isSubmitted) return;
    if (isTonesOnlyLocked && step != PracticeStep.tone) return;
    _activeStep = step;
    notifyListeners();
  }

  /// Picks Start (`''` for None) and advances automatically to Endings (or Tone if Ending is set).
  void selectStart(String initial) {
    if (isSubmitted || isTonesOnlyLocked) return;
    var nextNucleus = _draft.nucleus;
    var nextCoda = _draft.coda;
    if (nextNucleus != null &&
        _settings.constraintMode == ConstraintMode.guided) {
      final ending = '$nextNucleus${nextCoda ?? ''}';
      final valid = _constraintEngine.pool.any(
        (e) => e.initial == initial && '${e.nucleus}${e.coda}' == ending,
      );
      if (!valid) {
        nextNucleus = null;
        nextCoda = null;
      }
    }
    _draft = _draft.copyWith(
      initial: initial,
      nucleus: nextNucleus,
      coda: nextCoda,
      tone: null,
    );
    _activeStep = nextNucleus == null ? PracticeStep.ending : PracticeStep.tone;
    notifyListeners();
  }

  /// Picks one of the 57 Endings and advances to Tones (or Start if Start is unselected).
  void selectEnding(String finalStr) {
    if (isSubmitted || isTonesOnlyLocked) return;
    final (nucleus, coda) = JyutpingConstants.splitFinal(finalStr);
    _draft = _draft.copyWith(nucleus: nucleus, coda: coda, tone: null);
    _activeStep = _draft.initial == null
        ? PracticeStep.start
        : PracticeStep.tone;
    notifyListeners();
  }

  /// Picks Tone and immediately submits when Start and Ending are filled.
  Future<void> selectToneAndSubmit(int tone) async {
    if (isSubmitted) return;
    _draft = _draft.copyWith(tone: tone);
    if (_draft.initial == null) {
      _activeStep = PracticeStep.start;
      notifyListeners();
      return;
    }
    if (_draft.nucleus == null) {
      _activeStep = PracticeStep.ending;
      notifyListeners();
      return;
    }
    if (canSubmit) {
      await submit();
    } else {
      notifyListeners();
    }
  }

  void toggleInitial(String value) {
    if (isSubmitted || isTonesOnlyLocked) return;
    _draft = _draft.copyWith(initial: _draft.initial == value ? null : value);
    notifyListeners();
  }

  void toggleNucleus(String value) {
    if (isSubmitted || isTonesOnlyLocked) return;
    _draft = _draft.copyWith(nucleus: _draft.nucleus == value ? null : value);
    notifyListeners();
  }

  void toggleCoda(String value) {
    if (isSubmitted || isTonesOnlyLocked) return;
    _draft = _draft.copyWith(coda: _draft.coda == value ? null : value);
    notifyListeners();
  }

  void toggleTone(int value) {
    if (isSubmitted) return;
    _draft = _draft.copyWith(tone: _draft.tone == value ? null : value);
    notifyListeners();
  }

  void clearSlot(ComponentType component) {
    if (isSubmitted) return;
    if (isTonesOnlyLocked && component != ComponentType.tone) return;
    switch (component) {
      case ComponentType.initial:
        _draft = _draft.copyWith(initial: null);
      case ComponentType.nucleus:
        _draft = _draft.copyWith(nucleus: null);
      case ComponentType.coda:
        _draft = _draft.copyWith(coda: null);
      case ComponentType.tone:
        _draft = _draft.copyWith(tone: null);
    }
    notifyListeners();
  }

  void clearAll() {
    if (isSubmitted) return;
    if (isTonesOnlyLocked) {
      _draft = _draft.copyWith(tone: null);
      _activeStep = PracticeStep.tone;
    } else {
      _draft = const DraftInputState();
      _activeStep = PracticeStep.start;
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
      _activeStep = PracticeStep.start;
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
