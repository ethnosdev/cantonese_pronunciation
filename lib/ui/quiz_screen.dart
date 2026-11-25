import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/jyutping_constants.dart';
import '../core/syllable_models.dart';
import '../data/stats_repository.dart';
import '../state/quiz_controller.dart';
import 'widgets/answer_slots_bar.dart';
import 'widgets/feedback_tone_wheel_panel.dart';
import 'widgets/jyutping_keyboard.dart';

/// Phone-first primary quiz screen fitting narrow screens without scrolling.
class QuizScreen extends StatelessWidget {
  const QuizScreen({
    super.key,
    required this.controller,
    required this.onOpenSoundboard,
    required this.onOpenStats,
    required this.onOpenSettings,
  });

  final QuizController controller;
  final VoidCallback onOpenSoundboard;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): controller.playTarget,
        const SingleActivator(LogicalKeyboardKey.enter):
            controller.handleEnterKey,
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            controller.handleEnterKey,
        const SingleActivator(LogicalKeyboardKey.escape): controller.clearAll,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      if (controller.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final scale = MediaQuery.textScalerOf(
                            context,
                          ).scale(1.0);
                          final needsScroll =
                              scale > 1.05 || constraints.maxHeight < 550;
                          final content = _QuizBody(
                            controller: controller,
                            onOpenSoundboard: onOpenSoundboard,
                            onOpenStats: onOpenStats,
                            onOpenSettings: onOpenSettings,
                          );
                          if (needsScroll) {
                            return SingleChildScrollView(child: content);
                          }
                          return content;
                        },
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
}

class _QuizBody extends StatelessWidget {
  const _QuizBody({
    required this.controller,
    required this.onOpenSoundboard,
    required this.onOpenStats,
    required this.onOpenSettings,
  });

  final QuizController controller;
  final VoidCallback onOpenSoundboard;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(
          settings: settings,
          onTierChanged: (tier) =>
              controller.updateSettings(settings.copyWith(tier: tier)),
          onFilterChanged: (filter) =>
              controller.updateSettings(settings.copyWith(focusFilter: filter)),
          onOpenSoundboard: onOpenSoundboard,
          onOpenStats: onOpenStats,
          onOpenSettings: onOpenSettings,
        ),
        const SizedBox(height: 4),
        _AudioControlStrip(
          autoPlay: settings.autoPlay,
          hasTarget: controller.currentTarget != null,
          onPlayTarget: controller.playTarget,
          onToggleAutoPlay: (v) =>
              controller.updateSettings(settings.copyWith(autoPlay: v)),
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
        const SizedBox(height: 6),
        AnswerSlotsBar(
          draft: controller.draft,
          result: controller.lastResult,
          isTonesOnlyLocked: controller.isTonesOnlyLocked,
          onClearSlot: controller.clearSlot,
        ),
        const SizedBox(height: 6),
        if (controller.currentTarget == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No syllables match the selected pool and filter.',
              textAlign: TextAlign.center,
            ),
          )
        else if (controller.lastResult != null)
          FeedbackToneWheelPanel(
            result: controller.lastResult!,
            onPlayTarget: controller.playTarget,
            onPlayGuess: controller.playGuess,
            onPlayToneEntry: controller.playEntry,
            onNext: controller.nextTurn,
          )
        else
          JyutpingKeyboard(
            draft: controller.draft,
            isGuided: settings.constraintMode == ConstraintMode.guided,
            isTonesOnlyLocked: controller.isTonesOnlyLocked,
            allowedInitials: controller.allowedInitials(),
            allowedNuclei: controller.allowedNuclei(),
            allowedCodas: controller.allowedCodas(),
            allowedTones: controller.allowedTones(),
            canSubmit: controller.canSubmit,
            onToggleInitial: controller.toggleInitial,
            onToggleNucleus: controller.toggleNucleus,
            onToggleCoda: controller.toggleCoda,
            onToggleTone: controller.toggleTone,
            onSubmit: controller.submit,
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.settings,
    required this.onTierChanged,
    required this.onFilterChanged,
    required this.onOpenSoundboard,
    required this.onOpenStats,
    required this.onOpenSettings,
  });

  final AppSettings settings;
  final void Function(DatasetTier) onTierChanged;
  final void Function(FocusFilter) onFilterChanged;
  final VoidCallback onOpenSoundboard;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PopupMenuButton<DatasetTier>(
            initialValue: settings.tier,
            onSelected: onTierChanged,
            itemBuilder: (_) => [
              for (final t in DatasetTier.values)
                PopupMenuItem(value: t, child: Text(t.label)),
            ],
            child: _CompactChip(
              icon: Icons.layers_outlined,
              label: _shortTier(settings.tier),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: PopupMenuButton<FocusFilter>(
            initialValue: settings.focusFilter,
            onSelected: onFilterChanged,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: AllFilter(),
                child: Text('All Syllables'),
              ),
              const PopupMenuItem(
                value: TonesOnlyFilter(),
                child: Text('Tones Only'),
              ),
              const PopupMenuDivider(),
              for (final g in ConfusableInitialGroup.values)
                PopupMenuItem(
                  value: InitialContrastFilter(g),
                  child: Text('Initials: ${g.label}'),
                ),
              const PopupMenuDivider(),
              for (final g in ConfusableFinalGroup.values)
                PopupMenuItem(
                  value: FinalContrastFilter(g),
                  child: Text('Finals: ${g.label}'),
                ),
            ],
            child: _CompactChip(
              icon: Icons.filter_list,
              label: settings.focusFilter.label,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Soundboard',
          onPressed: onOpenSoundboard,
          icon: const Icon(Icons.grid_view_rounded, size: 20),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Stats',
          onPressed: onOpenStats,
          icon: const Icon(Icons.bar_chart_rounded, size: 20),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Settings & Credits',
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined, size: 20),
        ),
      ],
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

class _CompactChip extends StatelessWidget {
  const _CompactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 16),
        ],
      ),
    );
  }
}

class _AudioControlStrip extends StatelessWidget {
  const _AudioControlStrip({
    required this.autoPlay,
    required this.hasTarget,
    required this.onPlayTarget,
    required this.onToggleAutoPlay,
  });

  final bool autoPlay;
  final bool hasTarget;
  final VoidCallback onPlayTarget;
  final void Function(bool) onToggleAutoPlay;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: FilledButton.tonalIcon(
              onPressed: hasTarget ? onPlayTarget : null,
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Play Syllable'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilterChip(
          visualDensity: VisualDensity.compact,
          label: const Text('Auto-play', style: TextStyle(fontSize: 12)),
          selected: autoPlay,
          onSelected: onToggleAutoPlay,
        ),
      ],
    );
  }
}
