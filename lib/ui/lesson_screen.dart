import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/curriculum.dart';
import '../core/lesson_spec.dart';
import '../state/lesson_session_controller.dart';
import 'widgets/answer_slots_bar.dart';
import 'widgets/feedback_tone_wheel_panel.dart';
import 'widgets/jyutping_keyboard.dart';
import 'widgets/pitch_contour_painter.dart';

/// Distraction-free runner for standard lessons and standalone Daily Review.
class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.controller,
    required this.onRetryLesson,
    this.onOpenNextLesson,
    this.onReviewMore,
  });

  final LessonSessionController controller;
  final VoidCallback onRetryLesson;
  final void Function(LessonSpec nextLesson)? onOpenNextLesson;
  final VoidCallback? onReviewMore;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _lastFeedbackSeq = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant LessonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _lastFeedbackSeq = widget.controller.feedbackSequence;
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final seq = widget.controller.feedbackSequence;
    if (seq != _lastFeedbackSeq) {
      _lastFeedbackSeq = seq;
      final fb = widget.controller.currentFeedback;
      if (fb != null) {
        if (fb.isCorrect) {
          HapticFeedback.lightImpact();
        } else {
          HapticFeedback.heavyImpact();
        }
      }
    }
  }

  Future<void> _handleCloseRequested() async {
    final ctrl = widget.controller;
    if (ctrl.phase == SessionPhase.summary || ctrl.submittedCount == 0) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Lesson?'),
        content: const Text(
          'Your progress in this unfinished session will not be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final ctrl = widget.controller;

    final shortcuts = isCurrent
        ? <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.space): () =>
                ctrl.playCurrentPrompt(),
            const SingleActivator(LogicalKeyboardKey.enter): () =>
                ctrl.handleEnterKey(),
            const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
                ctrl.handleEnterKey(),
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                _handleCloseRequested(),
          }
        : const <ShortcutActivator, VoidCallback>{};

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleCloseRequested();
        }
      },
      child: CallbackShortcuts(
        bindings: shortcuts,
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: ListenableBuilder(
                    listenable: ctrl,
                    builder: (context, _) {
                      if (ctrl.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LessonTopBar(
                            controller: ctrl,
                            onClose: _handleCloseRequested,
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                6,
                                12,
                                16,
                              ),
                              child: _buildPhaseBody(context, ctrl),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseBody(
    BuildContext context,
    LessonSessionController ctrl,
  ) {
    switch (ctrl.phase) {
      case SessionPhase.hearAndCompare:
        return _HearAndCompareView(controller: ctrl);
      case SessionPhase.warmup:
      case SessionPhase.trial:
        return _ActiveTrialView(controller: ctrl);
      case SessionPhase.feedback:
        return _FeedbackView(controller: ctrl);
      case SessionPhase.summary:
        return _SummaryView(
          controller: ctrl,
          onRetryLesson: widget.onRetryLesson,
          onOpenNextLesson: widget.onOpenNextLesson,
          onReviewMore: widget.onReviewMore,
          onBackToPath: () => Navigator.of(context).pop(),
        );
    }
  }
}

class _LessonTopBar extends StatelessWidget {
  const _LessonTopBar({required this.controller, required this.onClose});

  final LessonSessionController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final session = controller.session;
    final spec = controller.lessonSpec;
    String stepText = '';
    if (session != null) {
      switch (controller.phase) {
        case SessionPhase.hearAndCompare:
          stepText = 'Listen';
        case SessionPhase.warmup:
          stepText = 'Warmup ${session.warmupIndex + 1}/${session.warmupTotal}';
        case SessionPhase.trial:
        case SessionPhase.feedback:
          final fb = controller.currentFeedback;
          if (fb != null && fb.isWarmup) {
            stepText =
                'Warmup ${session.warmupIndex + 1}/${session.warmupTotal}';
          } else {
            stepText = '${session.gradedIndex + 1}/${session.gradedTotal}';
          }
        case SessionPhase.summary:
          stepText = 'Done';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  controller.isDailyReview
                      ? DailyReviewSpec.title
                      : '${spec?.numberLabel ?? ''} ${spec?.title ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: controller.progressFraction,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            stepText,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HearAndCompareView extends StatelessWidget {
  const _HearAndCompareView({required this.controller});

  final LessonSessionController controller;

  @override
  Widget build(BuildContext context) {
    final spec = controller.lessonSpec;
    final cards = controller.session?.hearAndCompareCards ?? const [];
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spec != null) ...[
          Card(
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                spec.cue,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (controller.audioError != null) ...[
          _AudioErrorBanner(
            message: controller.audioError!,
            onRetry: controller.playAllHearAndCompare,
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'Tap each sound to compare',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: controller.playAllHearAndCompare,
              icon: const Icon(Icons.playlist_play),
              label: const Text('Play All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _HearCompareTile(
            card: cards[i],
            active: controller.activeIntroCardIndex == i,
            onTap: () => controller.playHearAndCompareCard(i, cards[i].entry),
          ),
        ],
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: FilledButton(
            onPressed: controller.startPracticeFromIntro,
            child: const Text('Start Practice'),
          ),
        ),
      ],
    );
  }
}

class _HearCompareTile extends StatelessWidget {
  const _HearCompareTile({
    required this.card,
    required this.active,
    required this.onTap,
  });

  final ResolvedHearAndCompareCard card;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = card.item;
    return Material(
      color: active
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: active ? scheme.primary : scheme.outlineVariant,
              width: active ? 1.8 : 1.2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.volume_up_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.hint}  (${card.entry.syllable})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.tone != null) ...[
                const SizedBox(width: 8),
                PitchContourBox(
                  tone: item.tone!,
                  isCheckedTone: item.isCheckedTone,
                  width: 44,
                  height: 26,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveTrialView extends StatelessWidget {
  const _ActiveTrialView({required this.controller});

  final LessonSessionController controller;

  @override
  Widget build(BuildContext context) {
    final trial = controller.currentTrial;
    if (trial == null) return const SizedBox.shrink();

    if (trial.format == ExerciseFormat.slotAssembly) {
      return _SlotAssemblyTrial(controller: controller, trial: trial);
    }
    if (trial.format == ExerciseFormat.sameDifferent) {
      return _SameDifferentTrial(controller: controller, trial: trial);
    }
    return _ChoiceCardsTrial(controller: controller, trial: trial);
  }
}

class _SameDifferentTrial extends StatelessWidget {
  const _SameDifferentTrial({required this.controller, required this.trial});

  final LessonSessionController controller;
  final LessonTrial trial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clipIdx = controller.activePairClipIndex;
    final canAnswer = controller.canSubmitSameDifferent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.audioError != null) ...[
          _AudioErrorBanner(
            message: controller.audioError!,
            onRetry: controller.playPair,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          trial.promptText,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ClipBadge(label: 'Clip A', active: clipIdx == 0),
            const SizedBox(width: 12),
            _ClipBadge(label: 'Clip B', active: clipIdx == 1),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: controller.playPair,
            icon: const Icon(Icons.replay),
            label: const Text('Play Pair'),
          ),
        ),
        if (!canAnswer)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Tap Play Pair first to hear both clips.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 16),
        _TactileChoiceButton(
          label: 'Same',
          subtitle: 'Matching ${trial.differentProperty?.beginnerLabel ?? ''}',
          enabled: canAnswer,
          onTap: () => controller.submitSameDifferent(pickedSame: true),
        ),
        const SizedBox(height: 10),
        _TactileChoiceButton(
          label: 'Different',
          subtitle:
              'Contrasting ${trial.differentProperty?.beginnerLabel ?? ''}',
          enabled: canAnswer,
          onTap: () => controller.submitSameDifferent(pickedSame: false),
        ),
      ],
    );
  }
}

class _ClipBadge extends StatelessWidget {
  const _ClipBadge({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? scheme.primaryContainer : scheme.surfaceContainerLow,
        border: Border.all(
          color: active ? scheme.primary : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.volume_up,
            size: 15,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCardsTrial extends StatelessWidget {
  const _ChoiceCardsTrial({required this.controller, required this.trial});

  final LessonSessionController controller;
  final LessonTrial trial;

  @override
  Widget build(BuildContext context) {
    final useTwoColumns = trial.choices.length >= 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.audioError != null) ...[
          _AudioErrorBanner(
            message: controller.audioError!,
            onRetry: controller.playCurrentPrompt,
          ),
          const SizedBox(height: 8),
        ],
        Center(
          child: FilledButton.tonalIcon(
            onPressed: controller.playCurrentPrompt,
            icon: const Icon(Icons.volume_up),
            label: const Text('Replay'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          trial.promptText,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (!useTwoColumns)
          for (var i = 0; i < trial.choices.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _ChoiceCardTile(
              option: trial.choices[i],
              showContour: trial.showContoursOnButtons,
              onTap: () => controller.submitChoice(trial.choices[i]),
            ),
          ]
        else
          for (var r = 0; r < trial.choices.length; r += 2) ...[
            if (r > 0) const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ChoiceCardTile(
                    option: trial.choices[r],
                    showContour: trial.showContoursOnButtons,
                    onTap: () => controller.submitChoice(trial.choices[r]),
                  ),
                ),
                const SizedBox(width: 8),
                if (r + 1 < trial.choices.length)
                  Expanded(
                    child: _ChoiceCardTile(
                      option: trial.choices[r + 1],
                      showContour: trial.showContoursOnButtons,
                      onTap: () =>
                          controller.submitChoice(trial.choices[r + 1]),
                    ),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
      ],
    );
  }
}

class _ChoiceCardTile extends StatelessWidget {
  const _ChoiceCardTile({
    required this.option,
    required this.showContour,
    required this.onTap,
  });

  final ChoiceOption option;
  final bool showContour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant, width: 1.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (option.subtitle != null &&
                          option.subtitle!.isNotEmpty)
                        Text(
                          option.subtitle!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (showContour && option.tone != null) ...[
                  const SizedBox(width: 10),
                  PitchContourBox(
                    tone: option.tone!,
                    isCheckedTone: option.isCheckedTone,
                    width: 38,
                    height: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TactileChoiceButton extends StatelessWidget {
  const _TactileChoiceButton({
    required this.label,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: enabled ? scheme.surface : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: enabled
                    ? scheme.outline
                    : scheme.outlineVariant.withValues(alpha: 0.5),
                width: 1.3,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: enabled ? null : scheme.onSurfaceVariant,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: enabled ? scheme.primary : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotAssemblyTrial extends StatelessWidget {
  const _SlotAssemblyTrial({required this.controller, required this.trial});

  final LessonSessionController controller;
  final LessonTrial trial;

  @override
  Widget build(BuildContext context) {
    final mask = trial.slotMask ?? const SlotMask();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.audioError != null) ...[
          _AudioErrorBanner(
            message: controller.audioError!,
            onRetry: controller.playCurrentPrompt,
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: controller.playCurrentPrompt,
              icon: const Icon(Icons.volume_up, size: 18),
              label: const Text('Replay'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                trial.promptText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnswerSlotsBar(
          draft: controller.draft,
          result: null,
          useBeginnerLabels: true,
          lockedComponents: mask.lockedComponents,
          onClearSlot: controller.clearSlot,
        ),
        const SizedBox(height: 6),
        JyutpingKeyboard(
          draft: controller.draft,
          isGuided: mask.isGuided,
          useBeginnerLabels: true,
          visibleComponents: mask.visibleComponents,
          allowedInitials: controller.allowedInitials(),
          allowedNuclei: controller.allowedNuclei(),
          allowedCodas: controller.allowedCodas(),
          allowedTones: controller.allowedTones(),
          canSubmit: controller.canSubmitAssembly,
          onToggleInitial: controller.toggleInitial,
          onToggleNucleus: controller.toggleNucleus,
          onToggleCoda: controller.toggleCoda,
          onToggleTone: controller.toggleTone,
          onSubmit: controller.submitAssembly,
        ),
      ],
    );
  }
}

class _FeedbackView extends StatelessWidget {
  const _FeedbackView({required this.controller});

  final LessonSessionController controller;

  @override
  Widget build(BuildContext context) {
    final fb = controller.currentFeedback;
    if (fb == null) return const SizedBox.shrink();
    final trial = controller.currentTrial;
    final mask = trial?.slotMask;
    final useFullToneWheelPanel =
        fb.gradingResult != null &&
        mask != null &&
        mask.visibleComponents.length == 4;

    if (useFullToneWheelPanel) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnswerSlotsBar(
            draft: controller.draft,
            result: fb.gradingResult,
            useBeginnerLabels: true,
            lockedComponents: mask.lockedComponents,
            onClearSlot: (_) {},
          ),
          const SizedBox(height: 8),
          _FeedbackMotionWrapper(
            sequence: controller.feedbackSequence,
            isCorrect: fb.isCorrect,
            child: FeedbackToneWheelPanel(
              result: fb.gradingResult!,
              useBeginnerLabels: true,
              onPlayTarget: () => controller.playEntry(fb.target),
              onPlayGuess: () {
                if (fb.guessedEntry != null) {
                  controller.playEntry(fb.guessedEntry!);
                }
              },
              onPlayToneEntry: controller.playEntry,
              onNext: controller.advanceAfterFeedback,
            ),
          ),
        ],
      );
    }

    return _FeedbackMotionWrapper(
      sequence: controller.feedbackSequence,
      isCorrect: fb.isCorrect,
      child: _InlineComparisonFeedbackCard(
        controller: controller,
        feedback: fb,
      ),
    );
  }
}

class _FeedbackMotionWrapper extends StatelessWidget {
  const _FeedbackMotionWrapper({
    required this.sequence,
    required this.isCorrect,
    required this.child,
  });

  final int sequence;
  final bool isCorrect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('fb_${sequence}_$isCorrect'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: isCorrect ? 160 : 180),
      builder: (context, t, body) {
        if (isCorrect) {
          final scale = 0.97 + (0.03 * t);
          return Transform.scale(scale: scale, child: body);
        }
        // +/-4 px horizontal shake on miss.
        final dx = math.sin(t * math.pi * 4) * 4.0 * (1.0 - t);
        return Transform.translate(offset: Offset(dx, 0), child: body);
      },
      child: child,
    );
  }
}

class _InlineComparisonFeedbackCard extends StatelessWidget {
  const _InlineComparisonFeedbackCard({
    required this.controller,
    required this.feedback,
  });

  final LessonSessionController controller;
  final TrialFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = feedback.isCorrect;
    final isChecked = const {'p', 't', 'k'}.contains(feedback.target.coda);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.check_circle : Icons.cancel,
                  color: ok ? scheme.primary : scheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ok ? 'Correct' : 'Not quite',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ok ? scheme.primary : scheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (feedback.isWarmup && feedback.pairEntry != null) ...[
              Text(
                '${feedback.isSamePair == true ? "Same" : "Different"} '
                '${feedback.differentProperty?.beginnerLabel ?? ""}: '
                '${feedback.target.syllable} vs. ${feedback.pairEntry!.syllable}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: controller.playPair,
                icon: const Icon(Icons.replay),
                label: const Text('Play Pair Again'),
              ),
            ] else ...[
              _ComparisonRow(
                roleLabel: 'Target',
                syllable: feedback.target.syllable,
                detailLabel:
                    feedback.expectedChoice?.label ??
                    Curriculum.plainToneLabel(feedback.target.tone),
                tone: feedback.target.tone,
                isCheckedTone: isChecked,
                showContour: feedback.showToneContours,
                isCorrectHighlight: true,
                onPlay: () => controller.playEntry(feedback.target),
              ),
              if (!ok) ...[
                const SizedBox(height: 8),
                _ComparisonRow(
                  roleLabel: 'Your Guess',
                  syllable:
                      feedback.guessedEntry?.syllable ??
                      feedback.gradingResult?.guessedKey.syllable ??
                      '—',
                  detailLabel:
                      feedback.selectedChoice?.label ??
                      (feedback.gradingResult != null
                          ? Curriculum.plainToneLabel(
                              feedback.gradingResult!.guessedKey.tone,
                            )
                          : ''),
                  tone:
                      feedback.guessedEntry?.tone ??
                      feedback.selectedChoice?.tone ??
                      feedback.gradingResult?.guessedKey.tone,
                  isCheckedTone: const {'p', 't', 'k'}.contains(
                    feedback.guessedEntry?.coda ??
                        feedback.gradingResult?.guessedKey.coda ??
                        '',
                  ),
                  showContour: feedback.showToneContours,
                  isCorrectHighlight: false,
                  onPlay: feedback.guessedEntry != null
                      ? () => controller.playEntry(feedback.guessedEntry!)
                      : null,
                ),
              ],
            ],
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: FilledButton(
                onPressed: controller.advanceAfterFeedback,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.roleLabel,
    required this.syllable,
    required this.detailLabel,
    required this.tone,
    required this.isCheckedTone,
    required this.showContour,
    required this.isCorrectHighlight,
    required this.onPlay,
  });

  final String roleLabel;
  final String syllable;
  final String detailLabel;
  final int? tone;
  final bool isCheckedTone;
  final bool showContour;
  final bool isCorrectHighlight;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCorrectHighlight
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.errorContainer.withValues(alpha: 0.35),
        border: Border.all(
          color: isCorrectHighlight ? scheme.primary : scheme.error,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$roleLabel · $syllable',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  detailLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (showContour && tone != null) ...[
            const SizedBox(width: 8),
            PitchContourBox(
              tone: tone!,
              isCheckedTone: isCheckedTone,
              color: isCorrectHighlight ? scheme.primary : scheme.error,
              width: 44,
              height: 24,
            ),
          ],
          if (onPlay != null)
            IconButton(
              tooltip: 'Play $roleLabel',
              onPressed: onPlay,
              icon: const Icon(Icons.volume_up),
            ),
        ],
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.controller,
    required this.onRetryLesson,
    required this.onOpenNextLesson,
    required this.onReviewMore,
    required this.onBackToPath,
  });

  final LessonSessionController controller;
  final VoidCallback onRetryLesson;
  final void Function(LessonSpec nextLesson)? onOpenNextLesson;
  final VoidCallback? onReviewMore;
  final VoidCallback onBackToPath;

  @override
  Widget build(BuildContext context) {
    final outcome = controller.outcome;
    if (outcome == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    if (outcome.isDailyReview) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.task_alt, size: 44, color: scheme.primary),
              const SizedBox(height: 10),
              Text(
                'Daily Review Complete',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Reviewed ${outcome.reviewedCount} skills  •  '
                '${outcome.advancedSkillCount} advanced, '
                '${outcome.resetSkillCount} scheduled for tomorrow',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (outcome.reviewUpdates.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final u in outcome.reviewUpdates)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(u.displayLabel)),
                        Text(
                          u.lapsed
                              ? 'Reset → 1d'
                              : 'Next in ${u.newIntervalDays}d',
                          style: TextStyle(
                            color: u.lapsed ? scheme.error : scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 18),
              if (onReviewMore != null) ...[
                OutlinedButton(
                  onPressed: onReviewMore,
                  child: const Text('Review More'),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: onBackToPath,
                child: const Text('Back to Path'),
              ),
            ],
          ),
        ),
      );
    }

    final pct = (outcome.accuracy * 100).round();
    final nextLesson = outcome.unlockedNextLessonId != null
        ? Curriculum.lessonById(outcome.unlockedNextLessonId!)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              outcome.passed ? Icons.check_circle : Icons.refresh,
              size: 44,
              color: outcome.passed ? scheme.primary : scheme.secondary,
            ),
            const SizedBox(height: 10),
            Text(
              outcome.passed ? 'Lesson Complete' : 'Almost There',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'First-attempt accuracy: $pct% '
              '(${outcome.coreCorrect}/${outcome.coreTotal})',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              outcome.passed
                  ? (nextLesson != null
                        ? 'Next unlocked: ${nextLesson.numberLabel} ${nextLesson.title}'
                        : 'You completed the entire 7-unit course.')
                  : 'Reach 80% on first attempts to unlock the next lesson.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (outcome.seededSkillCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '${outcome.seededSkillCount} contrast skills added to Daily Review.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (nextLesson != null && onOpenNextLesson != null) ...[
              FilledButton(
                onPressed: () => onOpenNextLesson!(nextLesson),
                child: Text('Next: Lesson ${nextLesson.numberLabel}'),
              ),
              const SizedBox(height: 8),
            ] else if (!outcome.passed) ...[
              FilledButton(
                onPressed: onRetryLesson,
                child: const Text('Retry Lesson'),
              ),
              const SizedBox(height: 8),
            ],
            if (outcome.passed) ...[
              OutlinedButton(
                onPressed: onRetryLesson,
                child: const Text('Retry Lesson'),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: onBackToPath,
              child: const Text('Back to Path'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioErrorBanner extends StatelessWidget {
  const _AudioErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry Audio')),
        ],
      ),
    );
  }
}
