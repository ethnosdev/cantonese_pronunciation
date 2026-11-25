import 'dart:math';

import 'package:cantonese_pronunciation/core/jyutping_constants.dart';
import 'package:cantonese_pronunciation/core/syllable_grader.dart';
import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:cantonese_pronunciation/core/weighted_sampler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const m4 = SyllableEntry(
    syllable: 'm4',
    path: 'm/4/m4.opus',
    initial: '',
    nucleus: '',
    coda: 'm',
    tone: 4,
    initialGroup: 0,
    priority: 0,
  );
  const m1 = SyllableEntry(
    syllable: 'm1',
    path: 'm/1/m1.opus',
    initial: '',
    nucleus: '',
    coda: 'm',
    tone: 1,
    initialGroup: 0,
    priority: 1,
  );
  const gwaa1 = SyllableEntry(
    syllable: 'gwaa1',
    path: 'aa/1/gwaa1.opus',
    initial: 'gw',
    nucleus: 'aa',
    coda: '',
    tone: 1,
    initialGroup: 5,
    priority: 0,
  );
  const baa1 = SyllableEntry(
    syllable: 'baa1',
    path: 'aa/1/baa1.opus',
    initial: 'b',
    nucleus: 'aa',
    coda: '',
    tone: 1,
    initialGroup: 1,
    priority: 0,
  );
  const ga1 = SyllableEntry(
    syllable: 'ga1',
    path: 'a/1/ga1.opus',
    initial: 'g',
    nucleus: 'a',
    coda: '',
    tone: 1,
    initialGroup: 3,
    priority: 0,
  );

  group('SyllableGrader', () {
    test('normalizes Initial m to syllabic nasal and resolves unrecorded guess', () {
      final catalog = {m4.key: m4, m1.key: m1, gwaa1.key: gwaa1};

      // Tapping initial "m" + tone 4 matches m4 cleanly.
      final resOk = SyllableGrader.grade(
        target: m4,
        draft: const DraftInputState(initial: 'm', tone: 4),
        filter: const AllFilter(),
        lookupEntry: (k) => catalog[k],
        lookupToneFamily: (i, n, c) => [m1, m4],
      );
      expect(resOk.isAllCorrect, isTrue);
      expect(resOk.autoNormalizedSyllabicNasal, isTrue);
      expect(resOk.isGuessPlayable, isTrue);
      expect(resOk.toneFamily.length, 2);

      // Guessing unrecorded gw+aa+k+1 marks isGuessPlayable false.
      final resBad = SyllableGrader.grade(
        target: gwaa1,
        draft: const DraftInputState(
          initial: 'gw',
          nucleus: 'aa',
          coda: 'k',
          tone: 1,
        ),
        filter: const AllFilter(),
        lookupEntry: (k) => catalog[k],
        lookupToneFamily: (i, n, c) => [gwaa1],
      );
      expect(resBad.isAllCorrect, isFalse);
      expect(resBad.grades[ComponentType.coda]!.isCorrect, isFalse);
      expect(resBad.isGuessPlayable, isFalse);
    });

    test('records only tone component in stats during Tones Only drills', () {
      final res = SyllableGrader.grade(
        target: m4,
        draft: const DraftInputState(initial: '', nucleus: '', coda: 'm', tone: 1),
        filter: const TonesOnlyFilter(),
        lookupEntry: (k) => k == m1.key ? m1 : null,
        lookupToneFamily: (i, n, c) => [m1, m4],
      );
      expect(res.statsComponents, [ComponentType.tone]);
      expect(res.isGuessPlayable, isTrue);
    });
  });

  group('FocusFilter & WeightedSampler', () {
    test('sub-group contrast filters include expected syllables and syllabic nasals', () {
      const mNNg = FinalContrastFilter(ConfusableFinalGroup.mNNg);
      const aaA = FinalContrastFilter(ConfusableFinalGroup.aaA);
      const gwGroup = InitialContrastFilter(ConfusableInitialGroup.gwkwgk);

      expect(mNNg.matches(m4), isTrue);
      expect(mNNg.matches(baa1), isFalse);
      expect(aaA.matches(baa1), isTrue);
      expect(aaA.matches(ga1), isTrue);
      expect(gwGroup.matches(gwaa1), isTrue);
      expect(gwGroup.matches(baa1), isFalse);
    });

    test('weighted sampler favors high-error targets and avoids immediate repeats', () {
      final sampler = WeightedSampler(random: Random(42));
      const pool = [baa1, gwaa1];
      const stats = [
        ConfusionStat(
          component: ComponentType.initial,
          expected: 'gw',
          guessed: 'g',
          count: 20,
        ),
        ConfusionStat(
          component: ComponentType.initial,
          expected: 'b',
          guessed: 'b',
          count: 20,
        ),
      ];

      // With previousSyllable null, gwaa1 should be drawn noticeably more often.
      var gwCount = 0;
      for (var i = 0; i < 200; i++) {
        final pick = sampler.pickNext(pool: pool, stats: stats);
        if (pick == gwaa1) gwCount++;
      }
      expect(gwCount, greaterThan(115));

      // Immediate repeat suppression forces alternation when pool has 2 items.
      expect(
        sampler.pickNext(pool: pool, stats: stats, previousSyllable: 'gwaa1'),
        baa1,
      );
    });
  });
}
