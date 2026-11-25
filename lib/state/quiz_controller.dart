import 'package:flutter/foundation.dart';

import '../audio/audio_playback_service.dart';
import '../core/guided_constraint_engine.dart';
import '../core/syllable_grader.dart';
import '../core/syllable_models.dart';
import '../core/weighted_sampler.dart';
import '../data/audio_bundle_repository.dart';
import '../data/stats_repository.dart';
import '../data/syllable_repository.dart';

/// Coordinates quiz turns, Guided/Test constraints, grading, and audio calls.
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
  GradingResult? _lastResult;
  bool _isLoading = true;
  String? _audioError;

  AppSettings get settings => _settings;
  List<SyllableEntry> get activePool => _activePool;
  SyllableEntry? get currentTarget => _currentTarget;
  DraftInputState get draft => _draft;
  GradingResult? get lastResult => _lastResult;
  bool get isLoading => _isLoading;
  String? get audioError => _audioError;
  bool get isSubmitted => _lastResult != null;
  bool get isTonesOnlyLocked => _settings.focusFilter is TonesOnlyFilter;

  bool get canSubmit {
    if (isSubmitted || _currentTarget == null) return false;
    if (_settings.constraintMode == ConstraintMode.guided) {
      return _constraintEngine.canSubmit(_draft, _settings.focusFilter);
    }
    return _draft.canSubmit;
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
    return _constraintEngine.allowedTones(_draft, _settings.focusFilter);
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
    } else {
      _draft = const DraftInputState();
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
    await _playEntry(target);
  }

  Future<void> playGuess() async {
    final guess = _lastResult?.guessedEntry;
    if (guess == null) return;
    await _playEntry(guess);
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
    } else {
      _draft = const DraftInputState();
    }

    notifyListeners();
    if (playAudio) {
      // Trigger playback asynchronously without blocking frame update.
      Future<void>.microtask(() => _playEntry(next));
    }
  }

  Future<void> _playEntry(SyllableEntry entry) async {
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
