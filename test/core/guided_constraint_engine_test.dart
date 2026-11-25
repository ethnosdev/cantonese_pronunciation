import 'package:cantonese_pronunciation/core/guided_constraint_engine.dart';
import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const kyut2 = SyllableEntry(
    syllable: 'kyut2',
    path: 'yut/2/kyut2.opus',
    initial: 'k',
    nucleus: 'yu',
    coda: 't',
    tone: 2,
    initialGroup: 3,
    priority: 1,
  );
  const kyut3 = SyllableEntry(
    syllable: 'kyut3',
    path: 'yut/3/kyut3.opus',
    initial: 'k',
    nucleus: 'yu',
    coda: 't',
    tone: 3,
    initialGroup: 3,
    priority: 0,
  );
  const zeoi1 = SyllableEntry(
    syllable: 'zeoi1',
    path: 'eoi/1/zeoi1.opus',
    initial: 'z',
    nucleus: 'eo',
    coda: 'i',
    tone: 1,
    initialGroup: 4,
    priority: 0,
  );
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
  const hng6 = SyllableEntry(
    syllable: 'hng6',
    path: 'ng/6/hng6.opus',
    initial: 'h',
    nucleus: '',
    coda: 'ng',
    tone: 6,
    initialGroup: 3,
    priority: 0,
  );

  group('GuidedConstraintEngine', () {
    test('dynamically unlocks pri-1 checked tones only when pool includes them', () {
      final pri0Engine = GuidedConstraintEngine(const [kyut3]);
      final pri01Engine = GuidedConstraintEngine(const [kyut2, kyut3]);
      const draft = DraftInputState(initial: 'k', nucleus: 'yu', coda: 't');

      expect(pri0Engine.allowedTones(draft, const AllFilter()), {3});
      expect(pri01Engine.allowedTones(draft, const AllFilter()), {2, 3});
    });

    test('uses wildcard null and self-exclusion across slots', () {
      final engine = GuidedConstraintEngine(const [kyut3, zeoi1]);

      // Selecting eo leaves initials/tones open because coda=null is wildcard.
      const eoDraft = DraftInputState(nucleus: 'eo');
      expect(engine.allowedInitials(eoDraft), {'z'});
      expect(engine.allowedCodas(eoDraft), {'i'});
      expect(engine.allowedTones(eoDraft, const AllFilter()), {1});

      // Self-exclusion lets user switch nucleus while initial+tone stay chosen.
      const fullKyut = DraftInputState(
        initial: 'k',
        nucleus: 'yu',
        coda: 't',
        tone: 3,
      );
      expect(engine.allowedNuclei(fullKyut), {'yu'});

      // Blocking open eo on submit since no open-eo syllable exists.
      const invalidOpenEo = DraftInputState(
        initial: 'z',
        nucleus: 'eo',
        tone: 1,
      );
      expect(engine.canSubmit(invalidOpenEo, const AllFilter()), isFalse);
    });

    test('supports syllabic nasal Initial m/ng alias and hng in Guided Mode', () {
      final engine = GuidedConstraintEngine(const [m4, hng6]);

      expect(engine.allowedInitials(const DraftInputState()), {'', 'm', 'h'});
      const mDraft = DraftInputState(initial: 'm');
      expect(engine.allowedTones(mDraft, const AllFilter()), {4});
      expect(
        engine.canSubmit(mDraft.copyWith(tone: 4), const AllFilter()),
        isTrue,
      );

      const hngDraft = DraftInputState(initial: 'h', coda: 'ng', tone: 6);
      expect(engine.canSubmit(hngDraft, const AllFilter()), isTrue);
    });

    test('keeps all 6 tones enabled in Tones Only even on pri-0 pool', () {
      final pri0Engine = GuidedConstraintEngine(const [kyut3]);
      const prefilled = DraftInputState(initial: 'k', nucleus: 'yu', coda: 't');
      expect(
        pri0Engine.allowedTones(prefilled, const TonesOnlyFilter()),
        {1, 2, 3, 4, 5, 6},
      );
    });
  });
}
