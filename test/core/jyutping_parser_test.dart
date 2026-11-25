import 'package:cantonese_pronunciation/core/jyutping_parser.dart';
import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JyutpingParser', () {
    test('matches longest initials and vowel nuclei first', () {
      expect(
        JyutpingParser.parse('gwaa1'),
        const SyllableKey(initial: 'gw', nucleus: 'aa', coda: '', tone: 1),
      );
      expect(
        JyutpingParser.parse('kwong3'),
        const SyllableKey(initial: 'kw', nucleus: 'o', coda: 'ng', tone: 3),
      );
      expect(
        JyutpingParser.parse('ngaa4'),
        const SyllableKey(initial: 'ng', nucleus: 'aa', coda: '', tone: 4),
      );
      expect(
        JyutpingParser.parse('jyun5'),
        const SyllableKey(initial: 'j', nucleus: 'yu', coda: 'n', tone: 5),
      );
      expect(
        JyutpingParser.parse('oek6'),
        const SyllableKey(initial: '', nucleus: 'oe', coda: 'k', tone: 6),
      );
      expect(
        JyutpingParser.parse('zeoi2'),
        const SyllableKey(initial: 'z', nucleus: 'eo', coda: 'i', tone: 2),
      );
      expect(
        JyutpingParser.parse('ga1'),
        const SyllableKey(initial: 'g', nucleus: 'a', coda: '', tone: 1),
      );
      expect(
        JyutpingParser.parse('aai3'),
        const SyllableKey(initial: '', nucleus: 'aa', coda: 'i', tone: 3),
      );
      expect(
        JyutpingParser.parse('nak1'),
        const SyllableKey(initial: 'n', nucleus: 'a', coda: 'k', tone: 1),
      );
    });

    test('parses all four syllabic nasals m, hm, ng, hng', () {
      expect(
        JyutpingParser.parse('m4'),
        const SyllableKey(initial: '', nucleus: '', coda: 'm', tone: 4),
      );
      expect(
        JyutpingParser.parse('hm1'),
        const SyllableKey(initial: 'h', nucleus: '', coda: 'm', tone: 1),
      );
      expect(
        JyutpingParser.parse('ng5'),
        const SyllableKey(initial: '', nucleus: '', coda: 'ng', tone: 5),
      );
      expect(
        JyutpingParser.parse('hng6'),
        const SyllableKey(initial: 'h', nucleus: '', coda: 'ng', tone: 6),
      );
    });

    test('rejects invalid syllables', () {
      for (final bad in ['', 'baa', 'baa7', 'xx1', 'baaz1']) {
        expect(() => JyutpingParser.parse(bad), throwsFormatException);
      }
    });
  });
}
