import 'package:cantonese_pronunciation/core/guided_constraint_engine.dart';
import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  const aa1 = SyllableEntry(
    syllable: 'aa1',
    path: 'aa/1/aa1.opus',
    initial: '',
    nucleus: 'aa',
    coda: '',
    tone: 1,
    initialGroup: 0,
    priority: 0,
  );
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

    test('allowedStarts filters only on lockedEnding while allowedEndings filters by initial', () {
      final engine = GuidedConstraintEngine(const [kyut3, zeoi1, baa1]);

      // Unlocked Final (7.3 / Practice): all pool initials stay enabled.
      expect(engine.allowedStarts(), {'k', 'z', 'b'});
      // Locked Final (7.1): only initials valid with locked ending stay enabled.
      expect(engine.allowedStarts(lockedEnding: 'yut'), {'k'});
      expect(engine.allowedStarts(lockedEnding: 'eoi'), {'z'});

      // Endings narrow once an initial is chosen.
      expect(engine.allowedEndings(null), {'yut', 'eoi', 'aa'});
      expect(engine.allowedEndings('k'), {'yut'});

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

      expect(engine.allowedStarts(), {'', 'h'});
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

  group('ThreeStepAssemblyHelper', () {
    test('7.1 locked Final blocks blank initial, preserves locked Final on None, and ignores Final taps', () {
      final engine = GuidedConstraintEngine(const [aa1, baa1]);
      const locked = {PracticeStep.syllableFinal};
      const prefilled = DraftInputState(nucleus: 'aa', coda: '');

      // Cannot submit before explicit initial tap even with prefilled Final + tone.
      expect(
        ThreeStepAssemblyHelper.canSubmitAssembly(
          draft: prefilled.copyWith(tone: 1),
          engine: engine,
          filter: const AllFilter(),
          lockedSteps: locked,
          isGuided: true,
          preventToneLeaking: true,
        ),
        isFalse,
      );

      // Tapping tone early bounces to Step 1 without mutating draft.tone.
      final bounce = ThreeStepAssemblyHelper.selectToneAndSubmit(
        draft: prefilled,
        currentStep: PracticeStep.tone,
        tone: 1,
        engine: engine,
        filter: const AllFilter(),
        lockedSteps: locked,
        isGuided: true,
        preventToneLeaking: true,
      );
      expect(bounce.shouldSubmit, isFalse);
      expect(bounce.nextStep, PracticeStep.initial);
      expect(bounce.draft.tone, isNull);

      // Tapping locked Final is a no-op.
      final lockedTap = ThreeStepAssemblyHelper.selectEnding(
        draft: prefilled,
        currentStep: PracticeStep.initial,
        finalStr: 'yut',
        lockedSteps: locked,
      );
      expect(lockedTap.draft, prefilled);

      // Selecting None ('') keeps locked Final intact and advances to Tone.
      final pickedNone = ThreeStepAssemblyHelper.selectStart(
        draft: prefilled,
        currentStep: PracticeStep.initial,
        initial: '',
        engine: engine,
        lockedSteps: locked,
        isGuided: true,
      );
      expect(pickedNone.draft.initial, '');
      expect(pickedNone.draft.nucleus, 'aa');
      expect(pickedNone.nextStep, PracticeStep.tone);

      final readyTone = ThreeStepAssemblyHelper.selectToneAndSubmit(
        draft: pickedNone.draft,
        currentStep: pickedNone.nextStep,
        tone: 1,
        engine: engine,
        filter: const AllFilter(),
        lockedSteps: locked,
        isGuided: true,
        preventToneLeaking: true,
      );
      expect(readyTone.shouldSubmit, isTrue);
      expect(readyTone.draft.tone, 1);
    });

    test('7.2 locked empty Initial preserves '' and advances from Final to Tone', () {
      final engine = GuidedConstraintEngine(const [aa1]);
      const locked = {PracticeStep.initial};
      const prefilled = DraftInputState(initial: '');

      expect(
        ThreeStepAssemblyHelper.firstUnlockedStep(locked),
        PracticeStep.syllableFinal,
      );

      final pickedEnding = ThreeStepAssemblyHelper.selectEnding(
        draft: prefilled,
        currentStep: PracticeStep.syllableFinal,
        finalStr: 'aa',
        lockedSteps: locked,
      );
      expect(pickedEnding.draft.initial, '');
      expect(pickedEnding.draft.nucleus, 'aa');
      expect(pickedEnding.nextStep, PracticeStep.tone);

      final submit = ThreeStepAssemblyHelper.selectToneAndSubmit(
        draft: pickedEnding.draft,
        currentStep: pickedEnding.nextStep,
        tone: 1,
        engine: engine,
        filter: const AllFilter(),
        lockedSteps: locked,
        isGuided: true,
        preventToneLeaking: true,
      );
      expect(submit.shouldSubmit, isTrue);
    });

    test('bounces missing unlocked Ending without mutating tone while submitting syllabic nasal m4', () {
      final engine = GuidedConstraintEngine(const [baa1, m4]);

      // Incomplete 'b' bounces to Final with tone still null.
      final bounce = ThreeStepAssemblyHelper.selectToneAndSubmit(
        draft: const DraftInputState(initial: 'b'),
        currentStep: PracticeStep.tone,
        tone: 1,
        engine: engine,
        filter: const AllFilter(),
        lockedSteps: const {},
        isGuided: true,
        preventToneLeaking: true,
      );
      expect(bounce.shouldSubmit, isFalse);
      expect(bounce.nextStep, PracticeStep.syllableFinal);
      expect(bounce.draft.tone, isNull);

      // Syllabic nasal 'm' auto-normalizes and submits directly on Tone tap.
      final nasal = ThreeStepAssemblyHelper.selectToneAndSubmit(
        draft: const DraftInputState(initial: 'm'),
        currentStep: PracticeStep.tone,
        tone: 4,
        engine: engine,
        filter: const AllFilter(),
        lockedSteps: const {},
        isGuided: true,
        preventToneLeaking: true,
      );
      expect(nasal.shouldSubmit, isTrue);
      expect(nasal.draft.tone, 4);
    });
  });
}
