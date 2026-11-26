import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/audio_playback_service.dart';
import '../core/curriculum.dart';
import '../core/guided_constraint_engine.dart';
import '../core/lesson_session.dart';
import '../core/lesson_spec.dart';
import '../core/review_scheduler.dart';
import '../core/syllable_models.dart';
import '../data/audio_bundle_repository.dart';
import '../data/progress_repository.dart';
import '../data/stats_repository.dart';
import '../data/syllable_repository.dart';

/// Coordinates active lesson/Daily Review UI state, audio sequences, and commits.
class LessonSessionController extends ChangeNotifier {
  LessonSessionController({
    required SyllableRepository syllableRepository,
    required AudioBundleRepository bundleRepository,
    required StatsRepository statsRepository,
    required ProgressRepository progressRepository,
    required this.audioService,
    this.lessonSpec,
    Random? random,
    DateTime Function()? clock,
  }) : _syllableRepo = syllableRepository,
       _bundleRepo = bundleRepository,
       _statsRepo = statsRepository,
       _progressRepo = progressRepository,
       _random = random ?? Random(),
       _clock = clock ?? (() => DateTime.now().toUtc());

  final SyllableRepository _syllableRepo;
  final AudioBundleRepository _bundleRepo;
  final StatsRepository _statsRepo;
  final ProgressRepository _progressRepo;
  final AudioPlaybackService audioService;
  final LessonSpec? lessonSpec;
  final Random? _random;
  final DateTime Function()? _clock;

  LessonSession? _session;
  GuidedConstraintEngine _constraintEngine = GuidedConstraintEngine(const []);
  DraftInputState _draft = const DraftInputState();
  bool _isLoading = true;
  bool _autoPlay = true;
  bool _hasPlayedCurrentPair = false;
  int? _activePairClipIndex;
  int? _activeIntroCardIndex;
  int? _activeFeedbackClipIndex;
  int _feedbackPlaybackToken = 0;
  int _feedbackSequence = 0;
  String? _audioError;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  bool get isDailyReview => lessonSpec == null;
  LessonSession? get session => _session;
  DraftInputState get draft => _draft;
  bool get autoPlay => _autoPlay;
  bool get hasPlayedCurrentPair => _hasPlayedCurrentPair;
  int? get activePairClipIndex => _activePairClipIndex;
  int? get activeIntroCardIndex => _activeIntroCardIndex;
  int? get activeFeedbackClipIndex => _activeFeedbackClipIndex;
  int get feedbackSequence => _feedbackSequence;
  String? get audioError => _audioError;

  SessionPhase get phase => _session?.phase ?? SessionPhase.trial;
  LessonTrial? get currentTrial => _session?.currentTrial;
  TrialFeedback? get currentFeedback => _session?.currentFeedback;
  SessionOutcome? get outcome => _session?.outcome;
  int get submittedCount => _session?.submittedCount ?? 0;
  double get progressFraction => _session?.progressFraction ?? 0.0;

  bool get canSubmitSameDifferent {
    final trial = currentTrial;
    if (trial == null || trial.format != ExerciseFormat.sameDifferent) {
      return false;
    }
    return _autoPlay || _hasPlayedCurrentPair;
  }

  bool get canSubmitAssembly {
    final trial = currentTrial;
    if (trial == null ||
        trial.format != ExerciseFormat.slotAssembly ||
        phase != SessionPhase.trial) {
      return false;
    }
    final mask = trial.slotMask ?? const SlotMask();
    if (mask.isGuided) {
      return _constraintEngine.canSubmit(
        _draft,
        const AllFilter(),
        preventToneLeaking: _preventToneLeaking(trial),
      );
    }
    return _draft.canSubmit;
  }

  Future<void> initialize() async {
    _isLoading = true;
    _audioError = null;
    notifyListeners();

    final catalog = await _syllableRepo.loadAll();
    _autoPlay = await _statsRepo.loadAutoPlay();
    final scheduler = ReviewScheduler(clock: _clock);

    if (lessonSpec != null) {
      final pool = Curriculum.filterPool(lessonSpec!, catalog);
      _constraintEngine = GuidedConstraintEngine(pool);
      final confusionStats = lessonSpec!.isCumulativeReview
          ? await _statsRepo.loadAllStats()
          : const <ConfusionStat>[];
      _session = LessonSession.startLesson(
        lessonSpec!,
        catalog: catalog,
        confusionStats: confusionStats,
        random: _random,
        scheduler: scheduler,
      );
    } else {
      final due = await _progressRepo.loadDueReviewItems(_clock?.call());
      final hideContours = await _progressRepo
          .shouldHideToneContoursInDailyReview();
      _session = LessonSession.startDailyReview(
        due,
        catalog: catalog,
        hideToneContours: hideContours,
        random: _random,
        scheduler: scheduler,
      );
    }

    _prepareCurrentTurnDraft();
    _isLoading = false;
    if (_disposed) return;
    notifyListeners();

    if (_autoPlay &&
        (phase == SessionPhase.warmup || phase == SessionPhase.trial)) {
      unawaited(playCurrentPrompt());
    }
  }

  Future<void> startPracticeFromIntro() async {
    final s = _session;
    if (s == null || s.phase != SessionPhase.hearAndCompare) return;
    await audioService.stop();
    _activeIntroCardIndex = null;
    s.completeHearAndCompare();
    _prepareCurrentTurnDraft();
    notifyListeners();
    if (_autoPlay &&
        (s.phase == SessionPhase.warmup || s.phase == SessionPhase.trial)) {
      unawaited(playCurrentPrompt());
    }
  }

  Future<void> playHearAndCompareCard(int index, SyllableEntry entry) async {
    _audioError = null;
    _activeIntroCardIndex = index;
    notifyListeners();
    try {
      final path = await _bundleRepo.resolveAudioFilePath(entry.path);
      await audioService.playFile(path);
    } catch (_) {
      _setAudioError('Could not play audio. Tap card to try again.');
    }
  }

  Future<void> playAllHearAndCompare() async {
    final s = _session;
    if (s == null || s.hearAndCompareCards.isEmpty) return;
    _audioError = null;
    try {
      final paths = <String>[
        for (final card in s.hearAndCompareCards)
          await _bundleRepo.resolveAudioFilePath(card.entry.path),
      ];
      await audioService.playSequence(
        paths,
        gap: const Duration(milliseconds: 550),
        onClipStart: (idx) {
          if (_disposed) return;
          _activeIntroCardIndex = idx;
          notifyListeners();
        },
      );
    } catch (_) {
      _setAudioError('Could not play sequence. Tap again to retry.');
    } finally {
      if (!_disposed) {
        _activeIntroCardIndex = null;
        notifyListeners();
      }
    }
  }

  Future<void> playCurrentPrompt() async {
    final trial = currentTrial;
    if (trial == null) return;
    if (trial.format == ExerciseFormat.sameDifferent) {
      await playPair();
      return;
    }
    _audioError = null;
    notifyListeners();
    try {
      final path = await _bundleRepo.resolveAudioFilePath(trial.target.path);
      await audioService.playFile(path);
    } catch (_) {
      _setAudioError('Could not play audio. Tap Replay to try again.');
    }
  }

  Future<void> playPair() async {
    final trial = currentTrial;
    if (trial == null || trial.pairTarget == null) return;
    _audioError = null;
    _activePairClipIndex = 0;
    notifyListeners();
    try {
      final pathA = await _bundleRepo.resolveAudioFilePath(trial.target.path);
      final pathB = await _bundleRepo.resolveAudioFilePath(
        trial.pairTarget!.path,
      );
      _hasPlayedCurrentPair = true;
      await audioService.playSequence(
        [pathA, pathB],
        gap: const Duration(milliseconds: 450),
        onClipStart: (idx) {
          if (_disposed) return;
          _activePairClipIndex = idx;
          notifyListeners();
        },
      );
    } catch (_) {
      _setAudioError('Could not play pair audio. Tap Play Pair to try again.');
    } finally {
      if (!_disposed) {
        _activePairClipIndex = null;
        notifyListeners();
      }
    }
  }

  Future<void> playEntry(SyllableEntry entry) async {
    _audioError = null;
    _feedbackPlaybackToken++;
    if (_activeFeedbackClipIndex != null) {
      _activeFeedbackClipIndex = null;
      notifyListeners();
    }
    try {
      final path = await _bundleRepo.resolveAudioFilePath(entry.path);
      await audioService.playFile(path);
    } catch (_) {
      _setAudioError('Could not play audio clip.');
    }
  }

  /// Plays one feedback comparison entry (`0` Target, `1` Your Guess) with highlight state.
  Future<void> playComparisonClip(SyllableEntry entry, int clipIndex) async {
    _audioError = null;
    final myToken = ++_feedbackPlaybackToken;
    try {
      final path = await _bundleRepo.resolveAudioFilePath(entry.path);
      await audioService.playSequence(
        [path],
        onClipStart: (_) {
          if (_disposed || myToken != _feedbackPlaybackToken) return;
          _activeFeedbackClipIndex = clipIndex;
          notifyListeners();
        },
        onClipEnd: (_) {
          if (_disposed || myToken != _feedbackPlaybackToken) return;
          _activeFeedbackClipIndex = null;
          notifyListeners();
        },
      );
    } catch (_) {
      _setAudioError('Could not play audio clip.');
    } finally {
      if (!_disposed &&
          myToken == _feedbackPlaybackToken &&
          _activeFeedbackClipIndex != null) {
        _activeFeedbackClipIndex = null;
        notifyListeners();
      }
    }
  }

  Future<void> submitSameDifferent({required bool pickedSame}) async {
    final s = _session;
    if (s == null || s.phase != SessionPhase.warmup) return;
    final fb = s.submitSameDifferent(pickedSame: pickedSame);
    _feedbackSequence++;
    notifyListeners();
    await _playFeedbackAudio(fb);
  }

  Future<void> submitChoice(ChoiceOption option) async {
    final s = _session;
    if (s == null || s.phase != SessionPhase.trial) return;
    final fb = s.submitChoice(option);
    _feedbackSequence++;
    notifyListeners();
    await _playFeedbackAudio(fb);
  }

  Future<void> submitAssembly() async {
    final s = _session;
    if (s == null || !canSubmitAssembly) return;
    final fb = s.submitAssembly(_draft);
    _feedbackSequence++;
    notifyListeners();
    await _playFeedbackAudio(fb);
  }

  Future<void> advanceAfterFeedback() async {
    final s = _session;
    if (s == null || s.phase != SessionPhase.feedback) return;
    _feedbackPlaybackToken++;
    await audioService.stop();
    await audioService.clearTurnSources();
    _activePairClipIndex = null;
    _activeFeedbackClipIndex = null;
    _audioError = null;

    s.advanceAfterFeedback();
    if (s.phase == SessionPhase.summary) {
      await _commitCompletion(s);
    } else {
      _prepareCurrentTurnDraft();
    }

    if (_disposed) return;
    notifyListeners();

    if (_autoPlay &&
        (s.phase == SessionPhase.warmup || s.phase == SessionPhase.trial)) {
      unawaited(playCurrentPrompt());
    }
  }

  Future<void> handleEnterKey() async {
    switch (phase) {
      case SessionPhase.hearAndCompare:
        await startPracticeFromIntro();
      case SessionPhase.trial:
        if (canSubmitAssembly) {
          await submitAssembly();
        }
      case SessionPhase.feedback:
        await advanceAfterFeedback();
      case SessionPhase.warmup:
      case SessionPhase.summary:
        break;
    }
  }

  // ---------------- Unit 7 Slot Assembly Input ----------------

  Set<String> allowedInitials() => _constraintEngine.allowedInitials(_draft);
  Set<String> allowedNuclei() => _constraintEngine.allowedNuclei(_draft);
  Set<String> allowedCodas() => _constraintEngine.allowedCodas(_draft);
  Set<int> allowedTones() {
    final trial = currentTrial;
    return _constraintEngine.allowedTones(
      _draft,
      const AllFilter(),
      preventToneLeaking: trial != null && _preventToneLeaking(trial),
    );
  }

  void toggleInitial(String value) {
    if (_isComponentLocked(ComponentType.initial)) return;
    _draft = _draft.copyWith(
      initial: _draft.initial == value ? null : value,
    );
    notifyListeners();
  }

  void toggleNucleus(String value) {
    if (_isComponentLocked(ComponentType.nucleus)) return;
    _draft = _draft.copyWith(
      nucleus: _draft.nucleus == value ? null : value,
    );
    notifyListeners();
  }

  void toggleCoda(String value) {
    if (_isComponentLocked(ComponentType.coda)) return;
    _draft = _draft.copyWith(coda: _draft.coda == value ? null : value);
    notifyListeners();
  }

  void toggleTone(int value) {
    if (_isComponentLocked(ComponentType.tone)) return;
    _draft = _draft.copyWith(tone: _draft.tone == value ? null : value);
    notifyListeners();
  }

  void clearSlot(ComponentType component) {
    if (_isComponentLocked(component)) return;
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

  Future<void> _playFeedbackAudio(TrialFeedback fb) async {
    if (fb.isCorrect) {
      await audioService.stop();
      return;
    }
    try {
      const delay = Duration(milliseconds: 300);
      const gap = Duration(milliseconds: 450);
      if (fb.isWarmup && fb.pairEntry != null) {
        final pathA = await _bundleRepo.resolveAudioFilePath(fb.target.path);
        final pathB = await _bundleRepo.resolveAudioFilePath(
          fb.pairEntry!.path,
        );
        await audioService.playSequence(
          [pathA, pathB],
          initialDelay: delay,
          gap: gap,
          onClipStart: (idx) {
            if (_disposed) return;
            _activePairClipIndex = idx;
            notifyListeners();
          },
        );
      } else {
        final myToken = ++_feedbackPlaybackToken;
        final targetPath = await _bundleRepo.resolveAudioFilePath(
          fb.target.path,
        );
        final guessEntry = fb.guessedEntry;
        final paths = [
          targetPath,
          if (guessEntry != null && guessEntry.path != fb.target.path)
            await _bundleRepo.resolveAudioFilePath(guessEntry.path),
        ];
        await audioService.playSequence(
          paths,
          initialDelay: delay,
          gap: gap,
          onClipStart: (idx) {
            if (_disposed || myToken != _feedbackPlaybackToken) return;
            _activeFeedbackClipIndex = idx;
            notifyListeners();
          },
          onClipEnd: (_) {
            if (_disposed || myToken != _feedbackPlaybackToken) return;
            _activeFeedbackClipIndex = null;
            notifyListeners();
          },
        );
      }
    } catch (_) {
      _setAudioError('Could not play comparison audio.');
    } finally {
      if (!_disposed &&
          (_activePairClipIndex != null || _activeFeedbackClipIndex != null)) {
        _activePairClipIndex = null;
        _activeFeedbackClipIndex = null;
        notifyListeners();
      }
    }
  }

  Future<void> _commitCompletion(LessonSession s) async {
    await _statsRepo.recordAttemptBatch(s.pendingStats);
    final now = _clock?.call();
    if (s.isDailyReview) {
      await _progressRepo.applyReviewOutcomes(
        s.buildUpdatedReviewItems(reviewedAt: now),
      );
      return;
    }
    final spec = lessonSpec;
    final res = s.outcome;
    if (spec != null && res != null) {
      await _progressRepo.completeLessonAttempt(
        lessonId: spec.id,
        accuracy: res.accuracy,
        passed: res.passed,
        nextLessonId: res.unlockedNextLessonId,
        skillsToSeed: spec.seedSkills,
        completedAt: now,
      );
    }
  }

  void _prepareCurrentTurnDraft() {
    _hasPlayedCurrentPair = false;
    _activePairClipIndex = null;
    final trial = currentTrial;
    if (trial == null || trial.format != ExerciseFormat.slotAssembly) {
      _draft = const DraftInputState();
      return;
    }
    final mask = trial.slotMask ?? const SlotMask();
    _draft = DraftInputState(
      initial: mask.lockedComponents.contains(ComponentType.initial)
          ? trial.target.initial
          : null,
      nucleus: mask.lockedComponents.contains(ComponentType.nucleus)
          ? trial.target.nucleus
          : null,
      coda: mask.lockedComponents.contains(ComponentType.coda)
          ? trial.target.coda
          : null,
      tone: mask.lockedComponents.contains(ComponentType.tone)
          ? trial.target.tone
          : null,
    );
  }

  bool _isComponentLocked(ComponentType component) {
    final trial = currentTrial;
    if (trial == null || trial.format != ExerciseFormat.slotAssembly) {
      return false;
    }
    return trial.slotMask?.lockedComponents.contains(component) ?? false;
  }

  bool _preventToneLeaking(LessonTrial trial) {
    // Keep all 6 tones enabled in Guided assembly `u7_l1..l3`.
    return trial.sourceLessonId != 'u7_l4_open_42_keys';
  }

  void _setAudioError(String message) {
    if (_disposed) return;
    _audioError = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(audioService.stop());
    unawaited(audioService.clearTurnSources());
    super.dispose();
  }
}
