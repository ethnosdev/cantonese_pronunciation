import 'package:material_ui/material_ui.dart';

import '../../core/jyutping_constants.dart';
import '../../core/syllable_models.dart';

/// Compact 42-key phonological keyboard (19 initials, 9 nuclei, 8 codas, 6 tones).
class JyutpingKeyboard extends StatelessWidget {
  const JyutpingKeyboard({
    super.key,
    required this.draft,
    required this.isGuided,
    required this.isTonesOnlyLocked,
    required this.allowedInitials,
    required this.allowedNuclei,
    required this.allowedCodas,
    required this.allowedTones,
    required this.canSubmit,
    required this.onToggleInitial,
    required this.onToggleNucleus,
    required this.onToggleCoda,
    required this.onToggleTone,
    required this.onSubmit,
  });

  final DraftInputState draft;
  final bool isGuided;
  final bool isTonesOnlyLocked;
  final Set<String> allowedInitials;
  final Set<String> allowedNuclei;
  final Set<String> allowedCodas;
  final Set<int> allowedTones;
  final bool canSubmit;
  final void Function(String) onToggleInitial;
  final void Function(String) onToggleNucleus;
  final void Function(String) onToggleCoda;
  final void Function(int) onToggleTone;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BandContainer(
          title: 'Initials (tap again for ∅)',
          tint: scheme.primaryContainer.withValues(alpha: 0.28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final band in JyutpingConstants.initialBands)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      for (var i = 0; i < band.initials.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: _KeyButton(
                            label: band.initials[i],
                            selected: draft.initial == band.initials[i],
                            enabled:
                                !isTonesOnlyLocked &&
                                (!isGuided ||
                                    allowedInitials.contains(band.initials[i])),
                            onTap: () => onToggleInitial(band.initials[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _BandContainer(
          title: 'Vowel Nuclei',
          tint: scheme.secondaryContainer.withValues(alpha: 0.30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRow(
                JyutpingConstants.vowelNuclei.sublist(0, 5),
                selectedValue: draft.nucleus,
                allowed: allowedNuclei,
                locked: isTonesOnlyLocked,
                onTap: onToggleNucleus,
              ),
              const SizedBox(height: 3),
              _buildRow(
                JyutpingConstants.vowelNuclei.sublist(5, 9),
                selectedValue: draft.nucleus,
                allowed: allowedNuclei,
                locked: isTonesOnlyLocked,
                onTap: onToggleNucleus,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _BandContainer(
          title: 'Codas (tap again for open)',
          tint: scheme.tertiaryContainer.withValues(alpha: 0.28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRow(
                JyutpingConstants.codas.sublist(0, 5),
                selectedValue: draft.coda,
                allowed: allowedCodas,
                locked: isTonesOnlyLocked,
                prefix: '-',
                onTap: onToggleCoda,
              ),
              const SizedBox(height: 3),
              _buildRow(
                JyutpingConstants.codas.sublist(5, 8),
                selectedValue: draft.coda,
                allowed: allowedCodas,
                locked: isTonesOnlyLocked,
                prefix: '-',
                onTap: onToggleCoda,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _BandContainer(
          title: 'Tones',
          tint: scheme.surfaceContainerHigh,
          child: Row(
            children: [
              for (var i = 0; i < JyutpingConstants.tones.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _ToneKeyButton(
                    tone: JyutpingConstants.tones[i],
                    pitch: JyutpingConstants
                        .tonePitchLabels[JyutpingConstants.tones[i]]!,
                    selected: draft.tone == JyutpingConstants.tones[i],
                    enabled:
                        !isGuided ||
                        allowedTones.contains(JyutpingConstants.tones[i]),
                    onTap: () => onToggleTone(JyutpingConstants.tones[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: FilledButton(
            onPressed: canSubmit ? onSubmit : null,
            child: const Text('Submit'),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(
    List<String> keys, {
    required String? selectedValue,
    required Set<String> allowed,
    required bool locked,
    String prefix = '',
    required void Function(String) onTap,
  }) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _KeyButton(
              label: '$prefix${keys[i]}',
              selected: selectedValue == keys[i],
              enabled: !locked && (!isGuided || allowed.contains(keys[i])),
              onTap: () => onTap(keys[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _BandContainer extends StatelessWidget {
  const _BandContainer({
    required this.title,
    required this.tint,
    required this.child,
  });

  final String title;
  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: selected ? scheme.primary : scheme.surface,
          foregroundColor: selected ? scheme.onPrimary : scheme.onSurface,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ToneKeyButton extends StatelessWidget {
  const _ToneKeyButton({
    required this.tone,
    required this.pitch,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int tone;
  final String pitch;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: selected ? scheme.primary : scheme.surface,
          foregroundColor: selected ? scheme.onPrimary : scheme.onSurface,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$tone',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              pitch,
              style: TextStyle(
                fontSize: 9,
                color: selected
                    ? scheme.onPrimary.withValues(alpha: 0.9)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
