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

  /// All 57 attested Cantonese Finals grouped by base vowel / syllabic nasal.
  static const List<FinalGroup> finalGroups = [
    FinalGroup(
      label: 'aa',
      finals: ['aa', 'aai', 'aau', 'aam', 'aan', 'aang', 'aap', 'aat', 'aak'],
    ),
    FinalGroup(
      label: 'a',
      finals: ['ai', 'au', 'am', 'an', 'ang', 'ap', 'at', 'ak'],
    ),
    FinalGroup(
      label: 'e',
      finals: ['e', 'ei', 'eu', 'em', 'en', 'eng', 'ep', 'ek'],
    ),
    FinalGroup(label: 'eo', finals: ['eoi', 'eon', 'eot']),
    FinalGroup(
      label: 'i',
      finals: ['i', 'iu', 'im', 'in', 'ing', 'ip', 'it', 'ik'],
    ),
    FinalGroup(
      label: 'o',
      finals: ['o', 'oi', 'ou', 'on', 'ong', 'ot', 'ok'],
    ),
    FinalGroup(label: 'oe', finals: ['oe', 'oeng', 'oek']),
    FinalGroup(
      label: 'u',
      finals: ['u', 'ui', 'un', 'ung', 'ut', 'uk'],
    ),
    FinalGroup(label: 'yu', finals: ['yu', 'yun', 'yut']),
    FinalGroup(label: 'Syllabic nasals', finals: ['m', 'ng']),
  ];

  /// Splits a Cantonese Final such as `aam` or `ng` into `(nucleus, coda)`.
  static (String nucleus, String coda) splitFinal(String finalStr) {
    if (finalStr == 'm' || finalStr == 'ng') {
      return ('', finalStr);
    }
    for (final n in nucleiLongestFirst) {
      if (finalStr.startsWith(n)) {
        return (n, finalStr.substring(n.length));
      }
    }
    return ('', finalStr);
  }
}

/// Visual grouping of Cantonese Finals (Endings) by base vowel.
class FinalGroup {
  const FinalGroup({required this.label, required this.finals});

  final String label;
  final List<String> finals;
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
  zeroNgH('None / ng / h', {'', 'ng', 'h'});

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
