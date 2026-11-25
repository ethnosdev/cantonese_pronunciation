import 'jyutping_constants.dart';
import 'syllable_models.dart';

/// Deterministic longest-match-first parser for LSHK Jyutping syllables.
class JyutpingParser {
  const JyutpingParser._();

  /// Parses a complete Jyutping syllable such as "gwaa1" or "hng6".
  static SyllableKey parse(String syllable) {
    if (syllable.length < 2) {
      throw FormatException('Syllable too short: "$syllable"');
    }

    final toneChar = syllable[syllable.length - 1];
    final tone = int.tryParse(toneChar);
    if (tone == null || tone < 1 || tone > 6) {
      throw FormatException('Invalid tone "$toneChar" in "$syllable"');
    }

    final body = syllable.substring(0, syllable.length - 1);
    if (body == 'm') {
      return SyllableKey(initial: '', nucleus: '', coda: 'm', tone: tone);
    }
    if (body == 'hm') {
      return SyllableKey(initial: 'h', nucleus: '', coda: 'm', tone: tone);
    }
    if (body == 'ng') {
      return SyllableKey(initial: '', nucleus: '', coda: 'ng', tone: tone);
    }
    if (body == 'hng') {
      return SyllableKey(initial: 'h', nucleus: '', coda: 'ng', tone: tone);
    }

    var initial = '';
    var remainder = body;
    for (final candidate in JyutpingConstants.initialsLongestFirst) {
      if (body.startsWith(candidate)) {
        initial = candidate;
        remainder = body.substring(candidate.length);
        break;
      }
    }

    var nucleus = '';
    var coda = '';
    for (final candidate in JyutpingConstants.nucleiLongestFirst) {
      if (remainder.startsWith(candidate)) {
        nucleus = candidate;
        coda = remainder.substring(candidate.length);
        break;
      }
    }

    if (nucleus.isEmpty) {
      throw FormatException('Missing vowel nucleus in "$syllable"');
    }
    if (!JyutpingConstants.validCodas.contains(coda)) {
      throw FormatException('Invalid coda "$coda" in "$syllable"');
    }

    return SyllableKey(
      initial: initial,
      nucleus: nucleus,
      coda: coda,
      tone: tone,
    );
  }
}
