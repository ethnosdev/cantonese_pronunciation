import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/curriculum.dart';
import '../core/lesson_spec.dart';
import '../state/lesson_session_controller.dart';
import 'widgets/feedback_tone_wheel_panel.dart';
import 'widgets/pitch_contour_painter.dart';
import 'widgets/practice_slots_bar.dart';
import 'widgets/practice_step_keyboard.dart';
import 'widgets/uniform_two_column_grid.dart';

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
                            child: ctrl.phase == SessionPhase.hearAndCompare
                                ? _HearAndCompareView(controller: ctrl)
                                : (ctrl.phase == SessionPhase.trial &&
                                          ctrl.currentTrial?.format ==
                                              ExerciseFormat.slotAssembly
                                      ? Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            6,
                                            12,
                                            12,
                                          ),
                                          child: _SlotAssemblyTrial(
                                            controller: ctrl,
                                            trial: ctrl.currentTrial!,
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            6,
                                            12,
                                            16,
                                          ),
                                          child: _buildPhaseBody(context, ctrl),
                                        )),
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

    final showNotesButton =
        spec != null &&
        spec.introSummary.isNotEmpty &&
        (controller.phase == SessionPhase.warmup ||
            controller.phase == SessionPhase.trial ||
            controller.phase == SessionPhase.feedback);

    return Padding(
      padding: EdgeInsets.fromLTRB(4, 4, showNotesButton ? 4 : 12, 4),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    controller.isDailyReview
                        ? DailyReviewSpec.title
                        : (spec?.isCumulativeReview == true
                              ? spec!.title
                              : 'Lesson ${spec?.numberLabel ?? ''}'),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
          Flexible(
            child: Text(
              stepText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (showNotesButton)
            IconButton(
              tooltip: 'Lesson notes',
              onPressed: () =>
                  _showLessonNotesSheet(context, controller, spec),
              icon: const Icon(Icons.info_outline),
            ),
        ],
      ),
    );
  }

  Future<void> _showLessonNotesSheet(
    BuildContext context,
    LessonSessionController controller,
    LessonSpec spec,
  ) async {
    await controller.audioService.stop();
    if (!context.mounted) return;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetCtx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      spec.isCumulativeReview
                          ? spec.title
                          : 'Lesson ${spec.numberLabel} · ${spec.title}',
                      style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close notes',
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                spec.introSummary,
                style: Theme.of(sheetCtx).textTheme.bodyMedium,
              ),
              if (spec.phoneticsNote != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Phonetics & IPA',
                  style: Theme.of(sheetCtx).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  spec.phoneticsNote!,
                  style: Theme.of(sheetCtx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
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
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (spec != null) ...[
                  Card(
                    color: scheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            spec.introSummary,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (spec.phoneticsNote != null) ...[
                            const SizedBox(height: 4),
                            ExpansionTile(
                              title: const Text('Phonetics & IPA'),
                              initiallyExpanded: false,
                              dense: true,
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(bottom: 8),
                              shape: const Border(),
                              collapsedShape: const Border(),
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    spec.phoneticsNote!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            const SizedBox(height: 6),
                        ],
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
                    onTap: () =>
                        controller.playHearAndCompareCard(i, cards[i].entry),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46),
              child: FilledButton(
                onPressed: controller.startPracticeFromIntro,
                child: const Text('Start Practice'),
              ),
            ),
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
          subtitle: '',
          enabled: canAnswer,
          onTap: () => controller.submitSameDifferent(pickedSame: true),
        ),
        const SizedBox(height: 10),
        _TactileChoiceButton(
          label: 'Different',
          subtitle: '',
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
          UniformTwoColumnGrid(
            spacing: 8,
            runSpacing: 8,
            minTileHeight: 68,
            children: [
              for (final option in trial.choices)
                _ChoiceCardTile(
                  option: option,
                  showContour: trial.showContoursOnButtons,
                  isGridTile: true,
                  onTap: () => controller.submitChoice(option),
                ),
            ],
          ),
      ],
    );
  }
}

class _ChoiceCardTile extends StatelessWidget {
  const _ChoiceCardTile({
    required this.option,
    required this.showContour,
    this.isGridTile = false,
    required this.onTap,
  });

  final ChoiceOption option;
  final bool showContour;
  final bool isGridTile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 2.0);
    final minHeight = isGridTile ? 82.0 * scale : 64.0;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant, width: 1.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: option.tone != null
                ? _buildToneContent(scheme)
                : _buildSoundContent(context, scheme),
          ),
        ),
      ),
    );
  }

  Widget _buildToneContent(ColorScheme scheme) {
    final tone = option.tone!;
    final name = Curriculum.tonePlainNames[tone] ?? option.label;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$tone',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            name,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (showContour) ...[
          const SizedBox(height: 6),
          PitchContourBox(
            tone: tone,
            isCheckedTone: option.isCheckedTone,
            width: 44,
            height: 20,
          ),
        ],
      ],
    );
  }

  Widget _buildSoundContent(BuildContext context, ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              option.label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (option.subtitle != null && option.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              option.subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
        Text(
          trial.promptText,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: controller.playCurrentPrompt,
                icon: const Icon(Icons.volume_up, size: 18),
                label: const Text('Replay'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PracticeSlotsBar(
                draft: controller.draft,
                activeStep: controller.activeStep,
                result: null,
                lockedSteps: controller.lockedSteps,
                onSelectStep: controller.setActiveStep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PracticeStepKeyboard(
            activeStep: controller.activeStep,
            draft: controller.draft,
            selectedEnding: controller.selectedEnding,
            isGuided: mask.isGuided,
            allowedStarts: controller.allowedStarts(),
            allowedEndings: controller.allowedEndings(),
            allowedTones: controller.allowedTones(),
            onSelectStart: controller.selectStart,
            onSelectEnding: controller.selectEnding,
            onSelectTone: controller.selectToneAndSubmit,
          ),
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

    if (fb.gradingResult != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PracticeSlotsBar(
            draft: controller.draft,
            activeStep: null,
            result: fb.gradingResult,
            lockedSteps: controller.lockedSteps,
            onSelectStep: (_) {},
          ),
          const SizedBox(height: 8),
          _FeedbackMotionWrapper(
            sequence: controller.feedbackSequence,
            isCorrect: fb.isCorrect,
            child: FeedbackToneWheelPanel(
              result: fb.gradingResult!,
              activeClipIndex: controller.activeFeedbackClipIndex,
              onPlayTarget: () => controller.playComparisonClip(fb.target, 0),
              onPlayGuess: () {
                if (fb.guessedEntry != null) {
                  controller.playComparisonClip(fb.guessedEntry!, 1);
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
    final activeSlot = controller.activeFeedbackClipIndex;

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
                '${feedback.differentProperty?.shortLabel ?? ""}: '
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
                isPlaying: activeSlot == 0,
                isDimmed: activeSlot != null && activeSlot != 0,
                onPlay: () => controller.playComparisonClip(feedback.target, 0),
              ),
              if (!ok) ...[
                const SizedBox(height: 8),
                _ComparisonRow(
                  roleLabel: 'Your Guess',
                  syllable: feedback.guessedEntry?.syllable ?? '—',
                  detailLabel: feedback.selectedChoice?.label ?? '',
                  tone:
                      feedback.guessedEntry?.tone ??
                      feedback.selectedChoice?.tone,
                  isCheckedTone: const {'p', 't', 'k'}.contains(
                    feedback.guessedEntry?.coda ?? '',
                  ),
                  showContour: feedback.showToneContours,
                  isCorrectHighlight: false,
                  isPlaying: activeSlot == 1,
                  isDimmed: activeSlot != null && activeSlot != 1,
                  onPlay: feedback.guessedEntry != null
                      ? () => controller.playComparisonClip(
                          feedback.guessedEntry!,
                          1,
                        )
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
    this.isPlaying = false,
    this.isDimmed = false,
    required this.onPlay,
  });

  final String roleLabel;
  final String syllable;
  final String detailLabel;
  final int? tone;
  final bool isCheckedTone;
  final bool showContour;
  final bool isCorrectHighlight;
  final bool isPlaying;
  final bool isDimmed;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseFill = isCorrectHighlight
        ? scheme.primaryContainer
        : scheme.errorContainer;
    final bgColor = isPlaying ? baseFill : baseFill.withValues(alpha: 0.35);
    final borderColor = isCorrectHighlight ? scheme.primary : scheme.error;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: isDimmed ? 0.52 : 1.0,
      child: Semantics(
        button: onPlay != null,
        label: onPlay != null ? 'Play $roleLabel' : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(
              color: borderColor,
              width: isPlaying ? 2.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: isPlaying
                ? [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onPlay,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$roleLabel · $syllable',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          Text(
                            detailLabel,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (showContour && tone != null) ...[
                      const SizedBox(width: 8),
                      PitchContourBox(
                        tone: tone!,
                        isCheckedTone: isCheckedTone,
                        color: borderColor,
                        width: 44,
                        height: 24,
                      ),
                    ],
                    if (onPlay != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.volume_up, color: borderColor),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
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
    final isReview = controller.lessonSpec?.isCumulativeReview ?? false;
    final nextLesson = outcome.unlockedNextLessonId != null
        ? Curriculum.lessonById(outcome.unlockedNextLessonId!)
        : null;
    final nextTitle = nextLesson == null
        ? null
        : (nextLesson.isCumulativeReview
              ? nextLesson.title
              : '${nextLesson.numberLabel} ${nextLesson.title}');
    final nextButtonLabel = nextLesson == null
        ? null
        : (nextLesson.isCumulativeReview
              ? 'Next: ${nextLesson.title}'
              : 'Next: Lesson ${nextLesson.numberLabel}');

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
              outcome.passed
                  ? (isReview ? 'Review Complete' : 'Lesson Complete')
                  : 'Almost There',
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
                  ? (nextTitle != null
                        ? 'Next unlocked: $nextTitle'
                        : 'You completed the entire 7-unit course.')
                  : 'Reach 80% on first attempts to unlock the next lesson.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            if (nextButtonLabel != null && onOpenNextLesson != null) ...[
              FilledButton(
                onPressed: () => onOpenNextLesson!(nextLesson!),
                child: Text(nextButtonLabel),
              ),
              const SizedBox(height: 8),
            ] else if (!outcome.passed) ...[
              FilledButton(
                onPressed: onRetryLesson,
                child: Text(isReview ? 'Retry Review' : 'Retry Lesson'),
              ),
              const SizedBox(height: 8),
            ],
            if (outcome.passed) ...[
              OutlinedButton(
                onPressed: onRetryLesson,
                child: Text(isReview ? 'Retry Review' : 'Retry Lesson'),
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
