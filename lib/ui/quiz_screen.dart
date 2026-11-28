import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/jyutping_constants.dart';
import '../core/syllable_models.dart';
import '../data/stats_repository.dart';
import '../state/quiz_controller.dart';
import 'widgets/feedback_tone_wheel_panel.dart';
import 'widgets/practice_slots_bar.dart';
import 'widgets/practice_step_keyboard.dart';

/// 3-step (Initial -> Final -> Tone) Practice screen opened from the Home Drawer.
class QuizScreen extends StatelessWidget {
  const QuizScreen({
    super.key,
    required this.controller,
  });

  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final shortcuts = isCurrent
        ? <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.space):
                controller.playTarget,
            const SingleActivator(LogicalKeyboardKey.enter):
                controller.handleEnterKey,
            const SingleActivator(LogicalKeyboardKey.numpadEnter):
                controller.handleEnterKey,
            const SingleActivator(LogicalKeyboardKey.escape): controller.clearAll,
          }
        : const <ShortcutActivator, VoidCallback>{};

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Practice'),
            actions: [
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) =>
                    _PracticeOptionsMenu(controller: controller),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      if (controller.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _QuizBody(controller: controller);
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
}

class _QuizBody extends StatelessWidget {
  const _QuizBody({required this.controller});

  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: controller.currentTarget != null
                    ? controller.playTarget
                    : null,
                icon: const Icon(Icons.play_arrow, size: 22),
                label: const Text('Play'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PracticeSlotsBar(
                draft: controller.draft,
                activeStep: controller.activeStep,
                result: controller.lastResult,
                lockedSteps: controller.lockedSteps,
                onSelectStep: controller.setActiveStep,
              ),
            ),
          ],
        ),
        if (controller.audioError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              controller.audioError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildMainContent(settings),
        ),
      ],
    );
  }

  Widget _buildMainContent(AppSettings settings) {
    if (controller.currentTarget == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No syllables match the selected pool and filter.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (controller.lastResult != null) {
      return SingleChildScrollView(
        child: FeedbackToneWheelPanel(
          result: controller.lastResult!,
          activeClipIndex: controller.activeFeedbackClipIndex,
          onPlayTarget: controller.playTarget,
          onPlayGuess: controller.playGuess,
          onPlayToneEntry: controller.playEntry,
          onNext: controller.nextTurn,
        ),
      );
    }
    return PracticeStepKeyboard(
      activeStep: controller.activeStep,
      draft: controller.draft,
      selectedEnding: controller.selectedEnding,
      isGuided: settings.constraintMode == ConstraintMode.guided,
      allowedStarts: controller.allowedStarts(),
      allowedEndings: controller.allowedEndings(),
      allowedTones: controller.allowedTones(),
      onSelectStart: controller.selectStart,
      onSelectEnding: controller.selectEnding,
      onSelectTone: controller.selectToneAndSubmit,
    );
  }
}

enum _MenuAction { toggleGuided, toggleAutoPlay, pickFocus, pickTier }

class _PracticeOptionsMenu extends StatelessWidget {
  const _PracticeOptionsMenu({required this.controller});

  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    final isGuided = settings.constraintMode == ConstraintMode.guided;

    return PopupMenuButton<_MenuAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Practice options',
      onSelected: (action) => _handleAction(context, action, settings),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: _MenuAction.toggleGuided,
          checked: isGuided,
          child: const Text('Guided (dim invalid)'),
        ),
        CheckedPopupMenuItem(
          value: _MenuAction.toggleAutoPlay,
          checked: settings.autoPlay,
          child: const Text('Auto-play'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.pickFocus,
          child: Text('Focus: ${settings.focusFilter.label}'),
        ),
        PopupMenuItem(
          value: _MenuAction.pickTier,
          child: Text('Word Pool: ${_shortTier(settings.tier)}'),
        ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    _MenuAction action,
    AppSettings settings,
  ) async {
    switch (action) {
      case _MenuAction.toggleGuided:
        final nextMode = settings.constraintMode == ConstraintMode.guided
            ? ConstraintMode.test
            : ConstraintMode.guided;
        await controller.updateSettings(
          settings.copyWith(constraintMode: nextMode),
        );
      case _MenuAction.toggleAutoPlay:
        await controller.updateSettings(
          settings.copyWith(autoPlay: !settings.autoPlay),
        );
      case _MenuAction.pickFocus:
        final picked = await _showFocusPicker(context, settings.focusFilter);
        if (picked != null) {
          await controller.updateSettings(
            settings.copyWith(focusFilter: picked),
          );
        }
      case _MenuAction.pickTier:
        final picked = await _showTierPicker(context, settings.tier);
        if (picked != null) {
          await controller.updateSettings(settings.copyWith(tier: picked));
        }
    }
  }

  Future<FocusFilter?> _showFocusPicker(
    BuildContext context,
    FocusFilter current,
  ) {
    final options = <FocusFilter>[
      const AllFilter(),
      const TonesOnlyFilter(),
      for (final g in ConfusableInitialGroup.values) InitialContrastFilter(g),
      for (final g in ConfusableFinalGroup.values) FinalContrastFilter(g),
    ];

    return showDialog<FocusFilter>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Focus Filter'),
        children: [
          for (final filter in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(filter),
              child: Row(
                children: [
                  Expanded(child: Text(filter.label)),
                  if (filter == current)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<DatasetTier?> _showTierPicker(
    BuildContext context,
    DatasetTier current,
  ) {
    return showDialog<DatasetTier>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Word Pool'),
        children: [
          for (final tier in DatasetTier.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(tier),
              child: Row(
                children: [
                  Expanded(child: Text(tier.label)),
                  if (tier == current)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _shortTier(DatasetTier tier) {
    switch (tier) {
      case DatasetTier.pri0:
        return 'Real (2.5k)';
      case DatasetTier.pri0And1:
        return '6-Tone (4.3k)';
      case DatasetTier.allRecorded:
        return 'All (5.3k)';
    }
  }
}
