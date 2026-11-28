import 'package:material_ui/material_ui.dart';

import '../../core/curriculum.dart';
import '../../core/jyutping_constants.dart';
import '../../core/syllable_models.dart';
import 'pitch_contour_painter.dart';
import 'uniform_two_column_grid.dart';

/// Contextual 3-step keyboard showing Initial consonants (20), Finals (57), or Tones (6).
class PracticeStepKeyboard extends StatelessWidget {
  const PracticeStepKeyboard({
    super.key,
    required this.activeStep,
    required this.draft,
    required this.selectedEnding,
    required this.isGuided,
    required this.allowedStarts,
    required this.allowedEndings,
    required this.allowedTones,
    required this.onSelectStart,
    required this.onSelectEnding,
    required this.onSelectTone,
  });

  final PracticeStep activeStep;
  final DraftInputState draft;
  final String? selectedEnding;
  final bool isGuided;
  final Set<String> allowedStarts;
  final Set<String> allowedEndings;
  final Set<int> allowedTones;
  final void Function(String initial) onSelectStart;
  final void Function(String finalStr) onSelectEnding;
  final void Function(int tone) onSelectTone;

  @override
  Widget build(BuildContext context) {
    switch (activeStep) {
      case PracticeStep.initial:
        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: _StartKeyboard(
              selectedInitial: draft.initial,
              isGuided: isGuided,
              allowedStarts: allowedStarts,
              onSelectStart: onSelectStart,
            ),
          ),
        );
      case PracticeStep.syllableFinal:
        return _EndingsKeyboard(
          selectedEnding: selectedEnding,
          isGuided: isGuided,
          allowedEndings: allowedEndings,
          onSelectEnding: onSelectEnding,
        );
      case PracticeStep.tone:
        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: _TonesKeyboard(
              selectedTone: draft.tone,
              selectedEnding: selectedEnding,
              isGuided: isGuided,
              allowedTones: allowedTones,
              onSelectTone: onSelectTone,
            ),
          ),
        );
    }
  }
}

class _StartKeyboard extends StatelessWidget {
  const _StartKeyboard({
    required this.selectedInitial,
    required this.isGuided,
    required this.allowedStarts,
    required this.onSelectStart,
  });

  final String? selectedInitial;
  final bool isGuided;
  final Set<String> allowedStarts;
  final void Function(String initial) onSelectStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PracticeStep.initial.headerLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final band in JyutpingConstants.initialBands)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (var i = 0; i < band.initials.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _StepKeyButton(
                        label: band.initials[i],
                        selected: selectedInitial == band.initials[i],
                        enabled:
                            !isGuided ||
                            allowedStarts.contains(band.initials[i]),
                        minHeight: 44,
                        fontSize: 17,
                        onTap: () => onSelectStart(band.initials[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 2),
          _StepKeyButton(
            label: ComponentType.noneLabel,
            selected: selectedInitial == '',
            enabled: !isGuided || allowedStarts.contains(''),
            minHeight: 44,
            fontSize: 16,
            onTap: () => onSelectStart(''),
          ),
        ],
      ),
    );
  }
}

class _EndingsKeyboard extends StatelessWidget {
  const _EndingsKeyboard({
    required this.selectedEnding,
    required this.isGuided,
    required this.allowedEndings,
    required this.onSelectEnding,
  });

  final String? selectedEnding;
  final bool isGuided;
  final Set<String> allowedEndings;
  final void Function(String finalStr) onSelectEnding;

  static final List<({String label, int familyIndex})> _orderedEndings = [
    for (var f = 0; f < JyutpingConstants.finalGroups.length; f++)
      for (final ending in JyutpingConstants.finalGroups[f].finals)
        (label: ending, familyIndex: f),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const perRow = 6;
    const rowGap = 4.0;
    final rows = <List<({String label, int familyIndex})>>[];
    for (var i = 0; i < _orderedEndings.length; i += perRow) {
      rows.add(
        _orderedEndings.sublist(
          i,
          i + perRow > _orderedEndings.length ? _orderedEndings.length : i + perRow,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PracticeStep.syllableFinal.headerLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rowCount = rows.length;
                final totalGap = rowGap * (rowCount - 1);
                final rawRowHeight =
                    (constraints.maxHeight - totalGap) / rowCount;
                final rowHeight = rawRowHeight.clamp(24.0, 48.0);
                final oddTint = scheme.secondaryContainer.withValues(alpha: 0.48);

                final grid = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var r = 0; r < rows.length; r++) ...[
                      if (r > 0) const SizedBox(height: rowGap),
                      SizedBox(
                        height: rowHeight,
                        child: Row(
                          children: [
                            for (var c = 0; c < perRow; c++) ...[
                              if (c > 0) const SizedBox(width: 4),
                              if (c < rows[r].length)
                                Expanded(
                                  child: _StepKeyButton(
                                    label: rows[r][c].label,
                                    selected:
                                        selectedEnding == rows[r][c].label,
                                    enabled: !isGuided ||
                                        allowedEndings
                                            .contains(rows[r][c].label),
                                    minHeight: rowHeight,
                                    exactHeight: rowHeight,
                                    fontSize: 15,
                                    backgroundTint:
                                        rows[r][c].familyIndex.isOdd
                                        ? oddTint
                                        : null,
                                    onTap: () =>
                                        onSelectEnding(rows[r][c].label),
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox.shrink()),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                );
                if (rawRowHeight < 24.0) {
                  return SingleChildScrollView(child: grid);
                }
                return grid;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TonesKeyboard extends StatelessWidget {
  const _TonesKeyboard({
    required this.selectedTone,
    required this.selectedEnding,
    required this.isGuided,
    required this.allowedTones,
    required this.onSelectTone,
  });

  final int? selectedTone;
  final String? selectedEnding;
  final bool isGuided;
  final Set<int> allowedTones;
  final void Function(int tone) onSelectTone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isChecked =
        selectedEnding != null &&
        (selectedEnding!.endsWith('p') ||
            selectedEnding!.endsWith('t') ||
            selectedEnding!.endsWith('k'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          PracticeStep.tone.headerLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        UniformTwoColumnGrid(
          spacing: 8,
          runSpacing: 8,
          minTileHeight: 86,
          children: [
            for (final tone in JyutpingConstants.tones)
              _ToneTileButton(
                tone: tone,
                isCheckedTone: isChecked,
                selected: selectedTone == tone,
                enabled: !isGuided || allowedTones.contains(tone),
                onTap: () => onSelectTone(tone),
              ),
          ],
        ),
      ],
    );
  }
}

class _ToneTileButton extends StatelessWidget {
  const _ToneTileButton({
    required this.tone,
    required this.isCheckedTone,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int tone;
  final bool isCheckedTone;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = Curriculum.tonePlainNames[tone] ?? '';
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.8 : 1.3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$tone',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
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
              const SizedBox(height: 6),
              PitchContourBox(
                tone: tone,
                isCheckedTone: isCheckedTone,
                width: 44,
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepKeyButton extends StatelessWidget {
  const _StepKeyButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.minHeight,
    required this.fontSize,
    required this.onTap,
    this.exactHeight,
    this.backgroundTint,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final double minHeight;
  final double? exactHeight;
  final double fontSize;
  final Color? backgroundTint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: selected
            ? scheme.primary
            : (backgroundTint ?? scheme.surface),
        foregroundColor: selected ? scheme.onPrimary : scheme.onSurface,
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
      ),
    );

    if (exactHeight != null) {
      return SizedBox(height: exactHeight, child: button);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: button,
    );
  }
}
