/// Canonical LSHK Jyutping inventories and Focus Filter group definitions.
class JyutpingConstants {
  const JyutpingConstants._();

  /// Articulation bands matching jyutnet initial groups ig-1..ig-5.
  static const List<InitialBand> initialBands = [
    InitialBand(group: 1, label: 'Labials', initials: ['b', 'p', 'm', 'f']),
    InitialBand(group: 2, label: 'Alveolars', initials: ['d', 't', 'n', 'l']),
    InitialBand(group: 3, label: 'Velars', initials: ['g', 'k', 'ng', 'h']),
    InitialBand(group: 4, label: 'Labialized', initials: ['gw', 'kw', 'w']),
    InitialBand(group: 5, label: 'Sibilants', initials: ['z', 'c', 's', 'j']),
  ];

  /// Ordered longest-match-first for deterministic Jyutping parsing.
  static const List<String> initialsLongestFirst = [
    'gw',
    'kw',
    'ng',
    'b',
    'p',
    'm',
    'f',
    'd',
    't',
    'n',
    'l',
    'g',
    'k',
    'h',
    'z',
    'c',
    's',
    'j',
    'w',
  ];

  /// 9 vowel nuclei in keyboard display order.
  static const List<String> vowelNuclei = [
    'aa',
    'a',
    'e',
    'i',
    'o',
    'u',
    'yu',
    'oe',
    'eo',
  ];

  /// Ordered longest-match-first for deterministic nucleus parsing.
  static const List<String> nucleiLongestFirst = [
    'aa',
    'yu',
    'oe',
    'eo',
    'a',
    'e',
    'i',
    'o',
    'u',
  ];

  /// 8 codas in keyboard display order.
  static const List<String> codas = [
    'i',
    'u',
    'm',
    'n',
    'ng',
    'p',
    't',
    'k',
  ];

  /// Valid codas including empty string for open syllables.
  static const Set<String> validCodas = {
    '',
    'i',
    'u',
    'm',
    'n',
    'ng',
    'p',
    't',
    'k',
  };

  /// 6 Cantonese tones in LSHK Jyutping.
  static const List<int> tones = [1, 2, 3, 4, 5, 6];

  /// Chao pitch contour numbers displayed on tone buttons.
  static const Map<int, String> tonePitchLabels = {
    1: '55',
    2: '35',
    3: '33',
    4: '21',
    5: '23',
    6: '22',
  };
}

/// Visual grouping of consonant initials by place/manner of articulation.
class InitialBand {
  const InitialBand({
    required this.group,
    required this.label,
    required this.initials,
  });

  final int group;
  final String label;
  final List<String> initials;
}

/// Selectable contrast groups for Confusable Initials drills.
enum ConfusableInitialGroup {
  zcs('z / c / s', {'z', 'c', 's'}),
  gwkwgk('g / gw / k / kw', {'g', 'gw', 'k', 'kw'}),
  bp('b / p', {'b', 'p'}),
  dt('d / t', {'d', 't'}),
  nl('n / l', {'n', 'l'}),
  zeroNgH('∅ / ng / h', {'', 'ng', 'h'});

  const ConfusableInitialGroup(this.label, this.initials);

  final String label;
  final Set<String> initials;
}

/// Selectable contrast groups for Confusable Finals drills.
enum ConfusableFinalGroup {
  aaA('aa vs a'),
  oeEoYu('oe / eo / yu'),
  nNg('-n vs -ng'),
  mNNg('-m / -n / -ng'),
  ptk('-p / -t / -k');

  const ConfusableFinalGroup(this.label);

  final String label;
}
