import 'lesson_spec.dart';
import 'syllable_models.dart';

/// Complete 7-unit, 28-lesson beginner curriculum verified against `syllables.json`.
class Curriculum {
  const Curriculum._();

  /// Plain tone names (Chao digits excluded from interactive labels).
  static const Map<int, String> tonePlainNames = {
    1: 'High Level',
    2: 'High Rising',
    3: 'Mid Level',
    4: 'Low Falling',
    5: 'Low Rising',
    6: 'Low Level',
  };

  /// Formatted plain label for beginner tone choice buttons (`1 · High Level`).
  static String plainToneLabel(int tone) =>
      '$tone · ${tonePlainNames[tone] ?? ''}';

  /// 20 attested `pri0 + pri1` transparent open bases across `{b, d, f, l, m, s} × {aa, i, o, u}`.
  static const Set<String> transparentBases = {
    'baa',
    'bi',
    'bo',
    'bu',
    'daa',
    'di',
    'do',
    'faa',
    'fo',
    'fu',
    'laa',
    'li',
    'lo',
    'lu',
    'maa',
    'mi',
    'mo',
    'saa',
    'si',
    'so',
  };

  static const Set<String> _stopInitials = {'b', 'p', 'd', 't', 'g', 'k'};
  static const Set<String> _openVowels = {'aa', 'e', 'i', 'o', 'u'};
  static const Set<String> _checkedCodas = {'p', 't', 'k'};
  static const Set<String> _syllabicNasalBases = {'m', 'hm', 'ng', 'hng'};

  static final List<UnitSpec> units = [
    const UnitSpec(
      id: 'unit_1',
      number: 1,
      title: 'Core Tones',
    ),
    const UnitSpec(
      id: 'unit_2',
      number: 2,
      title: 'Stop Initials',
    ),
    const UnitSpec(
      id: 'unit_3',
      number: 3,
      title: 'All Six Tones',
    ),
    const UnitSpec(
      id: 'unit_4',
      number: 4,
      title: 'More Initials',
    ),
    const UnitSpec(
      id: 'unit_5',
      number: 5,
      title: 'Basic Finals',
    ),
    const UnitSpec(
      id: 'unit_6',
      number: 6,
      title: 'Advanced Finals',
    ),
    const UnitSpec(
      id: 'unit_7',
      number: 7,
      title: 'Full Syllables',
    ),
  ];

  static final List<LessonSpec> lessons = [
    // ---------------- Unit 1: Core Tones ----------------
    LessonSpec(
      id: 'u1_l1_high_vs_low',
      unitId: 'unit_1',
      numberLabel: '1.1',
      title: 'High (1) & Low (4)',
      introSummary:
          'Cantonese words change meaning with voice pitch. Hear the difference between steady High Level (Tone 1) and Low Falling (Tone 4).',
      phoneticsNote:
          'Linguists describe Cantonese tone heights with Chao pitch numbers on a 1 (lowest) to 5 (highest) scale, writing start and end pitch as two digits. Tone 1 stays steady near the top of your range (55), while Tone 4 starts low and drops to the bottom (21), often with light vocal fry (creaky voice).',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      differentProperty: ComponentType.tone,
      choices: const ['1', '4'],
      showContoursOnButtons: true,
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          transparentBases.contains(e.base) &&
          (e.tone == 1 || e.tone == 4),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: '1',
            label: '1 · High Level',
            hint: 'Steady high voice pitch',
            preferredSyllable: 'baa1',
            tone: 1,
          ),
          HearAndCompareItem(
            value: '4',
            label: '4 · Low Falling',
            hint: 'Drops gently down low',
            preferredSyllable: 'baa4',
            tone: 4,
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same tone?',
        differentProperty: ComponentType.tone,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u1_l1_high_vs_low',
          targetType: 'tone',
          targetValue: '1',
          displayLabel: 'Tone 1 · High Level',
        ),
        ContrastSkill(
          lessonId: 'u1_l1_high_vs_low',
          targetType: 'tone',
          targetValue: '4',
          displayLabel: 'Tone 4 · Low Falling',
        ),
      ],
    ),
    LessonSpec(
      id: 'u1_l2_rising_2',
      unitId: 'unit_1',
      numberLabel: '1.2',
      title: 'High Rising (2)',
      introSummary:
          'Tone 2 rises clearly upward from middle pitch to high pitch. Contrast High Rising (2) against High Level (1) and Low Falling (4).',
      phoneticsNote:
          'Tone 2 carries Chao contour 35, starting around mid pitch and scooping up to the top of your voice like a quick English question. Hearing its upward movement cleanly against steady Tone 1 (55) and sinking Tone 4 (21) sets an anchor for every other contour.',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      differentProperty: ComponentType.tone,
      choices: const ['1', '2', '4'],
      showContoursOnButtons: true,
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          transparentBases.contains(e.base) &&
          (e.tone == 1 || e.tone == 2 || e.tone == 4),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: '1',
            label: '1 · High Level',
            hint: 'Steady and high',
            preferredSyllable: 'saa1',
            tone: 1,
          ),
          HearAndCompareItem(
            value: '2',
            label: '2 · High Rising',
            hint: 'Scoops upward sharply',
            preferredSyllable: 'saa2',
            tone: 2,
          ),
          HearAndCompareItem(
            value: '4',
            label: '4 · Low Falling',
            hint: 'Low and sinking',
            preferredSyllable: 'saa4',
            tone: 4,
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same tone?',
        differentProperty: ComponentType.tone,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u1_l2_rising_2',
          targetType: 'tone',
          targetValue: '2',
          displayLabel: 'Tone 2 · High Rising',
        ),
      ],
    ),
    LessonSpec(
      id: 'u1_l3_mid_level_3',
      unitId: 'unit_1',
      numberLabel: '1.3',
      title: 'Mid Level (3)',
      introSummary:
          'Tone 3 holds steady right in the middle of your voice. Tell Mid Level (3) apart from Tones 1, 2, and 4.',
      phoneticsNote:
          'Tone 3 has Chao contour 33—held level-pitched in a relaxed middle register with no rise and no drop. Notice how it sits noticeably lower than High Level Tone 1 (55), yet stays steady instead of sinking like Low Falling Tone 4 (21).',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      differentProperty: ComponentType.tone,
      choices: const ['1', '2', '3', '4'],
      showContoursOnButtons: true,
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          transparentBases.contains(e.base) &&
          e.tone >= 1 &&
          e.tone <= 4,
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: '1',
            label: '1 · High Level',
            hint: 'Highest steady pitch',
            preferredSyllable: 'si1',
            tone: 1,
          ),
          HearAndCompareItem(
            value: '2',
            label: '2 · High Rising',
            hint: 'Climbs upward',
            preferredSyllable: 'si2',
            tone: 2,
          ),
          HearAndCompareItem(
            value: '3',
            label: '3 · Mid Level',
            hint: 'Relaxed middle level',
            preferredSyllable: 'si3',
            tone: 3,
          ),
          HearAndCompareItem(
            value: '4',
            label: '4 · Low Falling',
            hint: 'Low downward glide',
            preferredSyllable: 'si4',
            tone: 4,
          ),
        ],
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u1_l3_mid_level_3',
          targetType: 'tone',
          targetValue: '3',
          displayLabel: 'Tone 3 · Mid Level',
        ),
      ],
    ),
    LessonSpec(
      id: 'u1_l4_four_tone_check',
      unitId: 'unit_1',
      numberLabel: '1.4',
      title: 'Tones 1–4 Check',
      introSummary:
          'Pitch curves are hidden on the buttons now—identify Tones 1, 2, 3, and 4 by ear alone.',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      differentProperty: ComponentType.tone,
      choices: const ['1', '2', '3', '4'],
      showContoursOnButtons: false,
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          transparentBases.contains(e.base) &&
          e.tone >= 1 &&
          e.tone <= 4,
    ),

    // ---------------- Unit 2: Stop Initials ----------------
    LessonSpec(
      id: 'u2_l1_b_vs_p',
      unitId: 'unit_2',
      numberLabel: '2.1',
      title: 'b vs. p',
      introSummary:
          'Neither Cantonese b nor p uses vocal-cord buzz like English b. Tell them apart by breath: p releases a sharp puff of air while b does not.',
      phoneticsNote:
          'The opening consonant of a syllable is its initial consonant, and both b and p are voiceless bilabial stops made by closing the lips. The key contrast is aspiration (a burst of breath on release): Jyutping b is unaspirated IPA [p] (close to the p in English "spin"), whereas Jyutping p is aspirated IPA [pʰ] (like the p in "pin"). Note that IPA brackets mark exact speech sounds and differ from Jyutping spelling letters.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      differentProperty: ComponentType.initial,
      choices: const ['b', 'p'],
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty && (e.initial == 'b' || e.initial == 'p'),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'b',
            label: 'b · Unaspirated',
            hint: 'Lip closure released without a breath burst',
            preferredSyllable: 'baa1',
          ),
          HearAndCompareItem(
            value: 'p',
            label: 'p · Aspirated',
            hint: 'Sharp burst of breath',
            preferredSyllable: 'paa1',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same initial consonant?',
        differentProperty: ComponentType.initial,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u2_l1_b_vs_p',
          targetType: 'initial',
          targetValue: 'b',
          displayLabel: 'Initial b',
        ),
        ContrastSkill(
          lessonId: 'u2_l1_b_vs_p',
          targetType: 'initial',
          targetValue: 'p',
          displayLabel: 'Initial p',
        ),
      ],
    ),
    LessonSpec(
      id: 'u2_l2_d_vs_t',
      unitId: 'unit_2',
      numberLabel: '2.2',
      title: 'd vs. t',
      introSummary:
          'Tell tongue-tip stops d and t apart by breath burst: t pushes out a sharp puff of air, while d releases cleanly without it.',
      phoneticsNote:
          'Both d and t are voiceless alveolar stops formed with the tongue tip pressed against the ridge behind your upper teeth. Just like b and p, Cantonese d is unaspirated IPA [t] (closer to the t in English "stop") and t is aspirated IPA [tʰ] (like the t in "top").',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      differentProperty: ComponentType.initial,
      choices: const ['d', 't'],
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty && (e.initial == 'd' || e.initial == 't'),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'd',
            label: 'd · Unaspirated',
            hint: 'Tongue tip release without a breath burst',
            preferredSyllable: 'daa1',
          ),
          HearAndCompareItem(
            value: 't',
            label: 't · Aspirated',
            hint: 'Sharp burst of breath',
            preferredSyllable: 'taa1',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same initial consonant?',
        differentProperty: ComponentType.initial,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u2_l2_d_vs_t',
          targetType: 'initial',
          targetValue: 'd',
          displayLabel: 'Initial d',
        ),
        ContrastSkill(
          lessonId: 'u2_l2_d_vs_t',
          targetType: 'initial',
          targetValue: 't',
          displayLabel: 'Initial t',
        ),
      ],
    ),
    LessonSpec(
      id: 'u2_l3_g_vs_k',
      unitId: 'unit_2',
      numberLabel: '2.3',
      title: 'g vs. k',
      introSummary:
          'Contrast the back-of-mouth stops g and k: g releases with no breath burst, while k pushes out a clear puff of air.',
      phoneticsNote:
          'Cantonese g and k are voiceless velar stops formed by raising the back of the tongue against the velum at the back of your mouth. Unaspirated g corresponds to IPA [k] (like the k in English "sky"), whereas aspirated k corresponds to IPA [kʰ] (like the k in "key").',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      differentProperty: ComponentType.initial,
      choices: const ['g', 'k'],
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty && (e.initial == 'g' || e.initial == 'k'),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'g',
            label: 'g · Unaspirated',
            hint: 'Back-tongue release without a breath burst',
            preferredSyllable: 'gaa1',
          ),
          HearAndCompareItem(
            value: 'k',
            label: 'k · Aspirated',
            hint: 'Strong burst of breath',
            preferredSyllable: 'kaa1',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same initial consonant?',
        differentProperty: ComponentType.initial,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u2_l3_g_vs_k',
          targetType: 'initial',
          targetValue: 'g',
          displayLabel: 'Initial g',
        ),
        ContrastSkill(
          lessonId: 'u2_l3_g_vs_k',
          targetType: 'initial',
          targetValue: 'k',
          displayLabel: 'Initial k',
        ),
      ],
    ),
    LessonSpec(
      id: 'u2_l4_stops_review',
      unitId: 'unit_2',
      numberLabel: '2.4',
      title: 'All Six Stops',
      introSummary:
          'Identify all six stop initials (b, p, d, t, g, k) by both mouth position and breath burst.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      choices: const ['b', 'p', 'd', 't', 'g', 'k'],
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty && _stopInitials.contains(e.initial),
    ),
    LessonSpec(
      id: 'u2_review',
      unitId: 'unit_2',
      numberLabel: 'R2',
      title: 'Units 1–2 Review',
      introSummary:
          'Review Tones 1–4 from Unit 1 alongside all six stop initials from Unit 2.',
      poolTier: DatasetTier.pri0And1,
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      poolPredicate: (e) => e.nucleus.isNotEmpty,
      cumulativeReviewUpToUnit: 2,
    ),

    // ---------------- Unit 3: All Six Tones ----------------
    LessonSpec(
      id: 'u3_l1_rising_2_vs_5',
      unitId: 'unit_3',
      numberLabel: '3.1',
      title: 'Rising Tones (2 & 5)',
      introSummary:
          'Both Tone 2 and Tone 5 rise in pitch, but Tone 2 climbs much higher than gentle Low Rising (5).',
      phoneticsNote:
          'High Rising Tone 2 (35) starts near mid pitch and climbs all the way to the top of your range. Low Rising Tone 5 (23) begins lower and finishes near mid height, making its rise noticeably shorter and gentler.',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      differentProperty: ComponentType.tone,
      choices: const ['2', '5'],
      showContoursOnButtons: true,
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          !_checkedCodas.contains(e.coda) &&
          (e.tone == 2 || e.tone == 5),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: '2',
            label: '2 · High Rising',
            hint: 'Big rise up to high pitch',
            preferredSyllable: 'si2',
            tone: 2,
          ),
          HearAndCompareItem(
            value: '5',
            label: '5 · Low Rising',
            hint: 'Small rise up to middle pitch',
            preferredSyllable: 'si5',
            tone: 5,
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same tone?',
        differentProperty: ComponentType.tone,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u3_l1_rising_2_vs_5',
          targetType: 'tone',
          targetValue: '5',
          displayLabel: 'Tone 5 · Low Rising',
        ),
      ],
    ),
    LessonSpec(
      id: 'u3_l2_level_3_vs_6',
      unitId: 'unit_3',
      numberLabel: '3.2',
      title: 'Level Tones (3 & 6)',
      introSummary:
          'Both Tone 3 and Tone 6 stay steady without rising or falling—listen for Tone 6 sitting noticeably lower than Tone 3.',
      phoneticsNote:
          'Mid Level Tone 3 (33) holds steady in the middle of your voice, while Low Level Tone 6 (22) sits one clear step below it without dropping at the end. Compare Tone 6 (22) against Low Falling Tone 4 (21): Tone 6 stays level rather than sinking to the bottom.',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      differentProperty: ComponentType.tone,
      choices: const ['3', '6'],
      showContoursOnButtons: true,
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          !_checkedCodas.contains(e.coda) &&
          (e.tone == 3 || e.tone == 6),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: '3',
            label: '3 · Mid Level',
            hint: 'Steady middle pitch',
            preferredSyllable: 'si3',
            tone: 3,
          ),
          HearAndCompareItem(
            value: '6',
            label: '6 · Low Level',
            hint: 'Steady low pitch',
            preferredSyllable: 'si6',
            tone: 6,
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same tone?',
        differentProperty: ComponentType.tone,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u3_l2_level_3_vs_6',
          targetType: 'tone',
          targetValue: '6',
          displayLabel: 'Tone 6 · Low Level',
        ),
      ],
    ),
    LessonSpec(
      id: 'u3_l3_low_tones_mix',
      unitId: 'unit_3',
      numberLabel: '3.3',
      title: 'Mid & Low Tones',
      introSummary:
          'Tell apart the five closely spaced mid and low tones (2, 3, 4, 5, and 6) with pitch curves hidden on the buttons.',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      choices: const ['2', '3', '4', '5', '6'],
      showContoursOnButtons: false,
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          !_checkedCodas.contains(e.coda) &&
          e.tone >= 2 &&
          e.tone <= 6,
    ),
    LessonSpec(
      id: 'u3_l4_six_tone_check',
      unitId: 'unit_3',
      numberLabel: '3.4',
      title: 'Six-Tone Check',
      introSummary:
          'Identify all six Cantonese tones (1–6) across open and nasal syllables without button curves.',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      choices: const ['1', '2', '3', '4', '5', '6'],
      showContoursOnButtons: false,
      format: ExerciseFormat.choiceCards,
      coreCount: 28,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty && !_checkedCodas.contains(e.coda),
    ),
    LessonSpec(
      id: 'u3_review',
      unitId: 'unit_3',
      numberLabel: 'R3',
      title: 'Units 1–3 Review',
      introSummary:
          'Review all six tones together with the six stop initials from Unit 2.',
      poolTier: DatasetTier.pri0And1,
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      poolPredicate: (e) => e.nucleus.isNotEmpty,
      cumulativeReviewUpToUnit: 3,
    ),

    // ---------------- Unit 4: More Initials ----------------
    LessonSpec(
      id: 'u4_l1_n_vs_l',
      unitId: 'unit_4',
      numberLabel: '4.1',
      title: 'n vs. l',
      introSummary:
          'Initial n lets voice resonate through the nose before the tongue releases; initial l lets air flow smoothly around the sides of the tongue.',
      phoneticsNote:
          'Both Jyutping n (IPA [n]) and l (IPA [l]) place the tongue tip against the ridge behind your upper teeth, but n lowers the nasal passage while l keeps airflow oral along the tongue\'s sides. Many modern Hong Kong speakers merge initial n into l in casual speech, so careful listening helps keep standard pairs clear.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      differentProperty: ComponentType.initial,
      choices: const ['n', 'l'],
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty && (e.initial == 'n' || e.initial == 'l'),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'n',
            label: 'n · Nasal',
            hint: 'Resonates through nose first',
            preferredSyllable: 'naa4',
          ),
          HearAndCompareItem(
            value: 'l',
            label: 'l · Clear',
            hint: 'Clean lateral l',
            preferredSyllable: 'laa4',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same initial consonant?',
        differentProperty: ComponentType.initial,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u4_l1_n_vs_l',
          targetType: 'initial',
          targetValue: 'n',
          displayLabel: 'Initial n',
        ),
        ContrastSkill(
          lessonId: 'u4_l1_n_vs_l',
          targetType: 'initial',
          targetValue: 'l',
          displayLabel: 'Initial l',
        ),
      ],
    ),
    LessonSpec(
      id: 'u4_l2_m_f_h',
      unitId: 'unit_4',
      numberLabel: '4.2',
      title: 'm, f, h',
      introSummary:
          'Contrast closed-lip nasal m with lip-teeth fricative f and open breathy h.',
      phoneticsNote:
          'Initial m (IPA [m]) seals the lips while sound resonates through the nose. Initial f (IPA [f], lower lip brushing the upper teeth) and h (IPA [h], open throat airflow) are voiceless fricatives that sound close to English f and h.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      choices: const ['m', 'f', 'h'],
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          (e.initial == 'm' || e.initial == 'f' || e.initial == 'h'),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'm',
            label: 'm · Lips closed',
            hint: 'Nasal closure on the lips',
            preferredSyllable: 'maa1',
          ),
          HearAndCompareItem(
            value: 'f',
            label: 'f · Lip-teeth',
            hint: 'Like English f',
            preferredSyllable: 'faa1',
          ),
          HearAndCompareItem(
            value: 'h',
            label: 'h · Open breath',
            hint: 'Open breathy h',
            preferredSyllable: 'haa1',
          ),
        ],
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u4_l2_m_f_h',
          targetType: 'initial',
          targetValue: 'm',
          displayLabel: 'Initial m',
        ),
        ContrastSkill(
          lessonId: 'u4_l2_m_f_h',
          targetType: 'initial',
          targetValue: 'f',
          displayLabel: 'Initial f',
        ),
        ContrastSkill(
          lessonId: 'u4_l2_m_f_h',
          targetType: 'initial',
          targetValue: 'h',
          displayLabel: 'Initial h',
        ),
      ],
    ),
    LessonSpec(
      id: 'u4_l3_z_c_s_j',
      unitId: 'unit_4',
      numberLabel: '4.3',
      title: 'z, c, s, j',
      introSummary:
          'Hear unaspirated z (like ds in kids), aspirated c (sharp ts), hissing s, and glide j (always like y in yes).',
      phoneticsNote:
          'Jyutping z (IPA [ts]) and c (IPA [tsʰ]) are alveolar affricates pairing a brief tongue-tip stop with an s release—z has no breath burst, while c is strongly aspirated. Initial s (IPA [s]) is a smooth fricative, and Jyutping j is always the palatal glide IPA [j] (like y in "yes", never English j). Before rounded vowels (yu, oe, eo), z, c, and s also take on light lip rounding.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      choices: const ['z', 'c', 's', 'j'],
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          (e.initial == 'z' ||
              e.initial == 'c' ||
              e.initial == 's' ||
              e.initial == 'j'),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'z',
            label: 'z · Unaspirated ds',
            hint: 'No breath burst (ds)',
            preferredSyllable: 'zaa1',
          ),
          HearAndCompareItem(
            value: 'c',
            label: 'c · Aspirated ts',
            hint: 'Sharp breath burst (ts)',
            preferredSyllable: 'caa1',
          ),
          HearAndCompareItem(
            value: 's',
            label: 's · Smooth hiss',
            hint: 'Steady s sound',
            preferredSyllable: 'saa1',
          ),
          HearAndCompareItem(
            value: 'j',
            label: 'j · Glide y',
            hint: 'Like y in yes',
            preferredSyllable: 'jaa1',
          ),
        ],
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u4_l3_z_c_s_j',
          targetType: 'initial',
          targetValue: 'z',
          displayLabel: 'Initial z',
        ),
        ContrastSkill(
          lessonId: 'u4_l3_z_c_s_j',
          targetType: 'initial',
          targetValue: 'c',
          displayLabel: 'Initial c',
        ),
        ContrastSkill(
          lessonId: 'u4_l3_z_c_s_j',
          targetType: 'initial',
          targetValue: 's',
          displayLabel: 'Initial s',
        ),
        ContrastSkill(
          lessonId: 'u4_l3_z_c_s_j',
          targetType: 'initial',
          targetValue: 'j',
          displayLabel: 'Initial j',
        ),
      ],
    ),
    LessonSpec(
      id: 'u4_l4_gw_kw_w',
      unitId: 'unit_4',
      numberLabel: '4.4',
      title: 'gw, kw, w (vs. g, k)',
      introSummary:
          'Notice the rounded-lip w glide inside gw and kw compared with plain g, plain k, and standalone w.',
      phoneticsNote:
          'Jyutping gw (IPA [kʷ]) and kw (IPA [kʷʰ]) are labialized velar stops: your back tongue closes for g or k while your lips round at the same time (like "qu" in "square" without breath vs. "queen" with breath). Contrast them with unrounded g (IPA [k]) and k (IPA [kʰ]), and with pure lip-glide w (IPA [w]).',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      choices: const ['g', 'k', 'gw', 'kw', 'w'],
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          (e.initial == 'g' ||
              e.initial == 'k' ||
              e.initial == 'gw' ||
              e.initial == 'kw' ||
              e.initial == 'w'),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'g',
            label: 'g · Plain',
            hint: 'Unrounded, unaspirated stop',
            preferredSyllable: 'gaa1',
          ),
          HearAndCompareItem(
            value: 'k',
            label: 'k · Plain aspirated',
            hint: 'Unrounded, aspirated stop',
            preferredSyllable: 'kaa1',
          ),
          HearAndCompareItem(
            value: 'gw',
            label: 'gw · Rounded',
            hint: 'Unaspirated g + rounded lips',
            preferredSyllable: 'gwaa1',
          ),
          HearAndCompareItem(
            value: 'kw',
            label: 'kw · Rounded aspirated',
            hint: 'Aspirated k + rounded lips',
            preferredSyllable: 'kwaa1',
          ),
          HearAndCompareItem(
            value: 'w',
            label: 'w · Lip glide',
            hint: 'Smooth w glide',
            preferredSyllable: 'waa1',
          ),
        ],
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u4_l4_gw_kw_w',
          targetType: 'initial',
          targetValue: 'gw',
          displayLabel: 'Initial gw',
        ),
        ContrastSkill(
          lessonId: 'u4_l4_gw_kw_w',
          targetType: 'initial',
          targetValue: 'kw',
          displayLabel: 'Initial kw',
        ),
        ContrastSkill(
          lessonId: 'u4_l4_gw_kw_w',
          targetType: 'initial',
          targetValue: 'w',
          displayLabel: 'Initial w',
        ),
      ],
    ),
    LessonSpec(
      id: 'u4_l5_ng_vs_none',
      unitId: 'unit_4',
      numberLabel: '4.5',
      title: 'ng vs. None',
      introSummary:
          'Listen for a back-throat ng onset versus a syllable that begins directly on the vowel with no initial consonant.',
      phoneticsNote:
          'Jyutping ng at the start of a word is the velar nasal IPA [ŋ]—the same sound as the end of English "sing", placed at the opening of a syllable. A syllable with no initial consonant has a zero initial, labeled None in Lesson controls and written as ∅ in Soundboard and Practice slot previews. In casual Hong Kong speech, speakers often drop initial ng or add it before vowel-initial words, so ear training helps lock in standard forms.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      differentProperty: ComponentType.initial,
      choices: const ['ng', ''],
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty && (e.initial == 'ng' || e.initial == ''),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'ng',
            label: 'ng · Back nasal',
            hint: 'Starts like the ng in sing',
            preferredSyllable: 'ngaa4',
          ),
          HearAndCompareItem(
            value: '',
            label: 'None · Zero initial',
            hint: 'Begins directly on the vowel',
            preferredSyllable: 'aa4',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same initial consonant?',
        differentProperty: ComponentType.initial,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u4_l5_ng_vs_none',
          targetType: 'initial',
          targetValue: 'ng',
          displayLabel: 'Initial ng',
        ),
        ContrastSkill(
          lessonId: 'u4_l5_ng_vs_none',
          targetType: 'initial',
          targetValue: '',
          displayLabel: 'Initial None',
        ),
      ],
    ),
    LessonSpec(
      id: 'u4_review',
      unitId: 'unit_4',
      numberLabel: 'R4',
      title: 'Units 1–4 Review',
      introSummary:
          'Review all six tones together with every initial consonant taught in Units 2 and 4.',
      poolTier: DatasetTier.pri0And1,
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      poolPredicate: (e) => e.nucleus.isNotEmpty,
      cumulativeReviewUpToUnit: 4,
    ),

    // ---------------- Unit 5: Basic Finals ----------------
    LessonSpec(
      id: 'u5_l1_open_vowels',
      unitId: 'unit_5',
      numberLabel: '5.1',
      title: 'Open Vowels (aa–u)',
      introSummary:
          'Hear the five open vowels aa, e, i, o, and u when no ending consonant follows. Short a is saved for closed syllables in Unit 6.',
      phoneticsNote:
          'In Cantonese, everything after the initial consonant forms the Final, built from a vowel nucleus plus an optional ending coda. When the coda is empty, the five open vowels correspond to long broad qualities: aa = IPA [aː], e = IPA [ɛː], i = IPA [iː], o = IPA [ɔː], and u = IPA [uː].',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.nucleus,
      choices: const ['aa', 'e', 'i', 'o', 'u'],
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.coda.isEmpty &&
          (e.initial == 'b' || e.initial == 'l' || e.initial == 'g') &&
          _openVowels.contains(e.nucleus),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'aa',
            label: 'aa · "ah"',
            hint: 'Wide open jaw',
            preferredSyllable: 'laa1',
          ),
          HearAndCompareItem(
            value: 'e',
            label: 'e · "eh"',
            hint: 'Mid front vowel',
            preferredSyllable: 'le1',
          ),
          HearAndCompareItem(
            value: 'i',
            label: 'i · "ee"',
            hint: 'High front vowel',
            preferredSyllable: 'li1',
          ),
          HearAndCompareItem(
            value: 'o',
            label: 'o · "aw"',
            hint: 'Open rounded vowel',
            preferredSyllable: 'lo1',
          ),
          HearAndCompareItem(
            value: 'u',
            label: 'u · "oo"',
            hint: 'High rounded vowel',
            preferredSyllable: 'lu1',
          ),
        ],
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u5_l1_open_vowels',
          targetType: 'nucleus',
          targetValue: 'aa',
          displayLabel: 'Vowel aa',
        ),
        ContrastSkill(
          lessonId: 'u5_l1_open_vowels',
          targetType: 'nucleus',
          targetValue: 'e',
          displayLabel: 'Vowel e',
        ),
        ContrastSkill(
          lessonId: 'u5_l1_open_vowels',
          targetType: 'nucleus',
          targetValue: 'i',
          displayLabel: 'Vowel i',
        ),
        ContrastSkill(
          lessonId: 'u5_l1_open_vowels',
          targetType: 'nucleus',
          targetValue: 'o',
          displayLabel: 'Vowel o',
        ),
        ContrastSkill(
          lessonId: 'u5_l1_open_vowels',
          targetType: 'nucleus',
          targetValue: 'u',
          displayLabel: 'Vowel u',
        ),
      ],
    ),
    LessonSpec(
      id: 'u5_l2_glide_endings',
      unitId: 'unit_5',
      numberLabel: '5.2',
      title: 'Vowel Glides (-i, -u)',
      introSummary:
          'Hear whether a syllable ends directly on its vowel (None) or glides upward toward -i or -u.',
      phoneticsNote:
          'The trailing sound after a vowel nucleus is its coda (final element), making Final = Vowel + Coda. Front glide -i (IPA [i]) lifts the tongue toward "ee", and rounded glide -u (IPA [u]) rounds the lips toward "oo". Adding a glide makes the preceding vowel shorter and slightly higher in ei (IPA [ei]) and ou (IPA [ou]).',
      trialPrompt: 'Which vowel glide do you hear?',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.coda,
      choices: const ['', 'i', 'u'],
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          (e.coda == '' || e.coda == 'i' || e.coda == 'u'),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: '',
            label: 'None · Open',
            hint: 'Stops on the vowel',
            preferredSyllable: 'haa1',
          ),
          HearAndCompareItem(
            value: 'i',
            label: '-i · Front glide',
            hint: 'Glides up toward ee',
            preferredSyllable: 'haai1',
          ),
          HearAndCompareItem(
            value: 'u',
            label: '-u · Lip glide',
            hint: 'Rounds toward oo',
            preferredSyllable: 'haau1',
          ),
        ],
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u5_l2_glide_endings',
          targetType: 'coda',
          targetValue: '',
          displayLabel: 'Coda None',
        ),
        ContrastSkill(
          lessonId: 'u5_l2_glide_endings',
          targetType: 'coda',
          targetValue: 'i',
          displayLabel: 'Coda -i',
        ),
        ContrastSkill(
          lessonId: 'u5_l2_glide_endings',
          targetType: 'coda',
          targetValue: 'u',
          displayLabel: 'Coda -u',
        ),
      ],
    ),
    LessonSpec(
      id: 'u5_l3_nasal_endings',
      unitId: 'unit_5',
      numberLabel: '5.3',
      title: 'Final Nasals (-m/n/ng)',
      introSummary:
          'Identify where nasal resonance closes at the end of a syllable: -m shuts the lips, -n taps behind the teeth, and -ng closes at the back.',
      phoneticsNote:
          'Cantonese allows three nasal codas: bilabial -m (IPA [m]), alveolar -n (IPA [n]), and velar -ng (IPA [ŋ]). Before velar -ng, high vowels relax slightly—so -ing sounds like IPA [ɪŋ] (closer to English "sing") and -ung sounds like IPA [ʊŋ] (closer to "ohng").',
      trialPrompt: 'Which final consonant do you hear?',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.coda,
      differentProperty: ComponentType.coda,
      choices: const ['m', 'n', 'ng'],
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          (e.coda == 'm' || e.coda == 'n' || e.coda == 'ng'),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'm',
            label: '-m · Lips closed',
            hint: 'Lips press shut at end',
            preferredSyllable: 'saam1',
          ),
          HearAndCompareItem(
            value: 'n',
            label: '-n · Tongue front',
            hint: 'Tongue tip behind teeth',
            preferredSyllable: 'saan1',
          ),
          HearAndCompareItem(
            value: 'ng',
            label: '-ng · Back throat',
            hint: 'Open mouth, back nasal close',
            preferredSyllable: 'saang1',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same final consonant?',
        differentProperty: ComponentType.coda,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u5_l3_nasal_endings',
          targetType: 'coda',
          targetValue: 'm',
          displayLabel: 'Coda -m',
        ),
        ContrastSkill(
          lessonId: 'u5_l3_nasal_endings',
          targetType: 'coda',
          targetValue: 'n',
          displayLabel: 'Coda -n',
        ),
        ContrastSkill(
          lessonId: 'u5_l3_nasal_endings',
          targetType: 'coda',
          targetValue: 'ng',
          displayLabel: 'Coda -ng',
        ),
      ],
    ),
    LessonSpec(
      id: 'u5_review',
      unitId: 'unit_5',
      numberLabel: 'R5',
      title: 'Units 1–5 Review',
      introSummary:
          'Review tones and initial consonants alongside open vowels, vowel glides, and nasal codas.',
      poolTier: DatasetTier.pri0And1,
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      poolPredicate: (e) => e.nucleus.isNotEmpty,
      cumulativeReviewUpToUnit: 5,
    ),

    // ---------------- Unit 6: Advanced Finals ----------------
    LessonSpec(
      id: 'u6_l1_aa_vs_a',
      unitId: 'unit_6',
      numberLabel: '6.1',
      title: 'Long aa vs. Short a',
      introSummary:
          'Contrast long wide aa (like saam) against short relaxed a (like sam) before the same ending.',
      phoneticsNote:
          'Long aa (IPA [aː]) holds the jaw wide open before the coda, whereas short a (IPA [ɐ]) snaps quickly into the coda with a shorter, more central sound similar to the vowel in English "cup". Short a never stands alone without a coda, so length and vowel quality work together before -i, -u, nasals, and stops.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.nucleus,
      differentProperty: ComponentType.nucleus,
      choices: const ['aa', 'a'],
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          e.coda.isNotEmpty &&
          (e.nucleus == 'aa' || e.nucleus == 'a'),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'aa',
            label: 'aa · Long',
            hint: 'Held wide "ah"',
            preferredSyllable: 'saam1',
          ),
          HearAndCompareItem(
            value: 'a',
            label: 'a · Short',
            hint: 'Quick central "uh"',
            preferredSyllable: 'sam1',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same vowel?',
        differentProperty: ComponentType.nucleus,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u6_l1_aa_vs_a',
          targetType: 'nucleus',
          targetValue: 'a',
          displayLabel: 'Vowel a',
        ),
      ],
    ),
    LessonSpec(
      id: 'u6_l2_yu_oe_eo',
      unitId: 'unit_6',
      numberLabel: '6.2',
      title: 'Rounded: yu, oe, eo',
      introSummary:
          'Contrast the three rounded front and central vowels: high tight yu, open mid oe, and short closed eo (used before -n and -t).',
      phoneticsNote:
          'To produce yu (IPA [yː]), hold your tongue in position for IPA [iː] ("ee") while rounding your lips into a tight circle. Vowel oe (IPA [œː]) is an open-mid front rounded sound used in open syllables and before -ng/-k, while short central rounded eo (IPA [ɵ]) replaces oe before -i, -n, and -t (so you hear syu1 vs. soe1 in open syllables and syun1 vs. seon1 before -n).',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.nucleus,
      choices: const ['yu', 'oe', 'eo'],
      choiceGroups: const [
        ['yu', 'oe'],
        ['yu', 'eo'],
      ],
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      pairedChoicesRequired: true,
      poolPredicate: (e) {
        if (e.nucleus.isEmpty) return false;
        final isOpenYuOe =
            (e.nucleus == 'yu' || e.nucleus == 'oe') &&
            e.coda.isEmpty &&
            (e.initial == 'z' || e.initial == 's') &&
            e.priority <= 1;
        final isClosedYuEo =
            (e.nucleus == 'yu' || e.nucleus == 'eo') &&
            (e.coda == 'n' || e.coda == 't') &&
            e.priority == 0;
        return isOpenYuOe || isClosedYuEo;
      },
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'yu',
            label: 'yu · High rounded',
            hint: 'Say "ee" with rounded lips',
            preferredSyllable: 'syu1',
          ),
          HearAndCompareItem(
            value: 'oe',
            label: 'oe · Open rounded',
            hint: 'Open rounded mid sound',
            preferredSyllable: 'soe1',
          ),
          HearAndCompareItem(
            value: 'eo',
            label: 'eo · Closed rounded',
            hint: 'Short rounded vowel before -n/-t',
            preferredSyllable: 'seon1',
          ),
        ],
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u6_l2_yu_oe_eo',
          targetType: 'nucleus',
          targetValue: 'yu',
          displayLabel: 'Vowel yu',
        ),
        ContrastSkill(
          lessonId: 'u6_l2_yu_oe_eo',
          targetType: 'nucleus',
          targetValue: 'oe',
          displayLabel: 'Vowel oe',
        ),
        ContrastSkill(
          lessonId: 'u6_l2_yu_oe_eo',
          targetType: 'nucleus',
          targetValue: 'eo',
          displayLabel: 'Vowel eo',
        ),
      ],
    ),
    LessonSpec(
      id: 'u6_l3_checked_stops',
      unitId: 'unit_6',
      numberLabel: '6.3',
      title: 'Final Stops (-p/t/k)',
      introSummary:
          'Hear unreleased final stops -p, -t, and -k cut the vowel short with no air puff afterward.',
      phoneticsNote:
          'Codas -p (IPA [p]), -t (IPA [t]), and -k (IPA [k]) close the lips, tongue tip, or back of tongue and stay closed—no breath releases at the end. Linguists call syllables ending in -p, -t, or -k checked tones (entering tones); their abrupt cut limits pitch to three level heights matching Tones 1, 3, and 6 (short Chao values 5, 3, and 2, paralleling 55, 33, and 22). Note that i and u also relax before -k into IPA [ɪk] and IPA [ʊk].',
      trialPrompt: 'Which final consonant do you hear?',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.coda,
      choices: const ['p', 't', 'k'],
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      pairedChoicesRequired: true,
      poolPredicate: (e) =>
          e.nucleus.isNotEmpty &&
          _checkedCodas.contains(e.coda) &&
          (e.tone == 1 || e.tone == 3 || e.tone == 6),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'p',
            label: '-p · Unreleased lips',
            hint: 'Lips press shut quickly',
            preferredSyllable: 'saap3',
            tone: 3,
            isCheckedTone: true,
          ),
          HearAndCompareItem(
            value: 't',
            label: '-t · Unreleased tongue',
            hint: 'Tongue stops air cleanly',
            preferredSyllable: 'saat3',
            tone: 3,
            isCheckedTone: true,
          ),
          HearAndCompareItem(
            value: 'k',
            label: '-k · Unreleased throat',
            hint: 'Back tongue catches abruptly',
            preferredSyllable: 'saak3',
            tone: 3,
            isCheckedTone: true,
          ),
        ],
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u6_l3_checked_stops',
          targetType: 'coda',
          targetValue: 'p',
          displayLabel: 'Coda -p',
        ),
        ContrastSkill(
          lessonId: 'u6_l3_checked_stops',
          targetType: 'coda',
          targetValue: 't',
          displayLabel: 'Coda -t',
        ),
        ContrastSkill(
          lessonId: 'u6_l3_checked_stops',
          targetType: 'coda',
          targetValue: 'k',
          displayLabel: 'Coda -k',
        ),
      ],
    ),
    LessonSpec(
      id: 'u6_l4_syllabic_nasals',
      unitId: 'unit_6',
      numberLabel: '6.4',
      title: 'Syllabic Nasals',
      introSummary:
          'Hear four standalone nasal words that carry tone without any vowel: m, hm, ng, and hng.',
      phoneticsNote:
          'Syllabic nasals use a nasal consonant as the entire syllable peak with no vowel at all: lip-closed m (IPA [m], as in m4 "not") and back-throat ng (IPA [ŋ], as in ng5 "five"). Adding a brief breathy h opening produces hm (IPA [hm]) and hng (IPA [hŋ]).',
      poolTier: DatasetTier.pri0And1,
      choices: const ['m', 'hm', 'ng', 'hng'],
      format: ExerciseFormat.choiceCards,
      coreCount: 20,
      pairedChoicesRequired: false,
      poolPredicate: (e) =>
          e.nucleus.isEmpty && _syllabicNasalBases.contains(e.base),
      warmup: const WarmupSpec(
        hearAndCompareItems: [
          HearAndCompareItem(
            value: 'm',
            label: 'm · Lip nasal',
            hint: 'Lips closed throughout',
            preferredSyllable: 'm4',
          ),
          HearAndCompareItem(
            value: 'hm',
            label: 'hm · Breath + lips',
            hint: 'Brief h breath into m',
            preferredSyllable: 'hm1',
          ),
          HearAndCompareItem(
            value: 'ng',
            label: 'ng · Back nasal',
            hint: 'Throat nasal alone',
            preferredSyllable: 'ng4',
          ),
          HearAndCompareItem(
            value: 'hng',
            label: 'hng · Breath + ng',
            hint: 'Brief h breath into ng',
            preferredSyllable: 'hng1',
          ),
        ],
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u6_l4_syllabic_nasals',
          targetType: 'syllable',
          targetValue: 'm',
          displayLabel: 'Syllabic nasal m',
        ),
        ContrastSkill(
          lessonId: 'u6_l4_syllabic_nasals',
          targetType: 'syllable',
          targetValue: 'hm',
          displayLabel: 'Syllabic nasal hm',
        ),
        ContrastSkill(
          lessonId: 'u6_l4_syllabic_nasals',
          targetType: 'syllable',
          targetValue: 'ng',
          displayLabel: 'Syllabic nasal ng',
        ),
        ContrastSkill(
          lessonId: 'u6_l4_syllabic_nasals',
          targetType: 'syllable',
          targetValue: 'hng',
          displayLabel: 'Syllabic nasal hng',
        ),
      ],
    ),
    LessonSpec(
      id: 'u6_review',
      unitId: 'unit_6',
      numberLabel: 'R6',
      title: 'Units 1–6 Review',
      introSummary:
          'Review all six tones, every initial consonant, vowel contrasts, final codas, and syllabic nasals across the full course.',
      poolTier: DatasetTier.pri0And1,
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      poolPredicate: (_) => true,
      cumulativeReviewUpToUnit: 6,
    ),

    // ---------------- Unit 7: Full Syllables ----------------
    LessonSpec(
      id: 'u7_l1_start_plus_tone',
      unitId: 'unit_7',
      numberLabel: '7.1',
      title: 'Initial + Tone',
      introSummary:
          'Build syllables using the 3-step Initial consonant, Final, and Tone builder. The Final is filled in for you—select Initial consonant and Tone.',
      phoneticsNote:
          'Unit 7 uses the same 3-step model as Practice: Initial consonant → Final → Tone. All 57 Finals combine a vowel nucleus and optional coda into one Step 2 choice. In this lesson Step 2 is locked for you, so focus on picking the Initial (tap None—shown as ∅ in the slot preview—when there is no consonant) and Tone.',
      trialPrompt: 'Build the initial consonant and tone.',
      poolTier: DatasetTier.pri0,
      format: ExerciseFormat.slotAssembly,
      coreCount: 24,
      poolPredicate: (e) => e.nucleus.isNotEmpty,
      slotMask: const SlotMask(
        lockedComponents: {ComponentType.nucleus, ComponentType.coda},
        isGuided: true,
      ),
    ),
    LessonSpec(
      id: 'u7_l2_vowel_ending_tone',
      unitId: 'unit_7',
      numberLabel: '7.2',
      title: 'Final + Tone',
      introSummary:
          'The initial consonant (or ∅ for None) is filled in—choose the matching Final and Tone on the 3-step keyboard.',
      trialPrompt: 'Build the final and tone.',
      poolTier: DatasetTier.pri0,
      format: ExerciseFormat.slotAssembly,
      coreCount: 24,
      poolPredicate: (e) => e.nucleus.isNotEmpty,
      slotMask: const SlotMask(
        lockedComponents: {ComponentType.initial},
        isGuided: true,
      ),
    ),
    LessonSpec(
      id: 'u7_l3_guided_42_keys',
      unitId: 'unit_7',
      numberLabel: '7.3',
      title: 'Guided Full Syllable',
      introSummary:
          'Assemble all three parts (Initial consonant, Final, and Tone) by ear while impossible syllable combinations remain dimmed as a guide.',
      trialPrompt: 'Build the full syllable (guided).',
      poolTier: DatasetTier.pri0,
      format: ExerciseFormat.slotAssembly,
      coreCount: 24,
      poolPredicate: (_) => true,
      slotMask: const SlotMask(
        lockedComponents: {},
        isGuided: true,
      ),
    ),
    LessonSpec(
      id: 'u7_l4_open_42_keys',
      unitId: 'unit_7',
      numberLabel: '7.4',
      title: 'Full Syllable',
      introSummary:
          'Final mastery check: transcribe full syllables across Initial consonant, Final, and Tone with no guided dimming.',
      trialPrompt: 'Build the full syllable.',
      poolTier: DatasetTier.pri0,
      format: ExerciseFormat.slotAssembly,
      coreCount: 28,
      poolPredicate: (_) => true,
      slotMask: const SlotMask(
        lockedComponents: {},
        isGuided: false,
      ),
    ),
  ];

  static final Map<String, LessonSpec> _lessonsById = {
    for (final l in lessons) l.id: l,
  };

  static final List<ContrastSkill> allSeedSkills = [
    for (final l in lessons) ...l.seedSkills,
  ];

  static List<LessonSpec> get standardLessons =>
      lessons.where((l) => !l.isCumulativeReview).toList(growable: false);

  static List<LessonSpec> get cumulativeReviews =>
      lessons.where((l) => l.isCumulativeReview).toList(growable: false);

  static LessonSpec? lessonById(String id) => _lessonsById[id];

  static String? nextLessonIdAfter(String lessonId) {
    final idx = lessons.indexWhere((l) => l.id == lessonId);
    if (idx < 0 || idx + 1 >= lessons.length) return null;
    return lessons[idx + 1].id;
  }

  static List<LessonSpec> lessonsForUnit(String unitId) => lessons
      .where((l) => l.unitId == unitId && !l.isCumulativeReview)
      .toList(growable: false);

  static LessonSpec? cumulativeReviewAfterUnit(String unitId) {
    for (final l in lessons) {
      if (l.isCumulativeReview && l.unitId == unitId) return l;
    }
    return null;
  }

  static int? unitNumberFor(String unitId) {
    for (final u in units) {
      if (u.id == unitId) return u.number;
    }
    return null;
  }

  /// Filters [catalog] to entries matching [spec]'s priority tier and predicate.
  static List<SyllableEntry> filterPool(
    LessonSpec spec,
    List<SyllableEntry> catalog,
  ) {
    return catalog
        .where((e) => spec.poolTier.includesPriority(e.priority) && spec.poolPredicate(e))
        .toList(growable: false);
  }

  /// Resolves attested entries where every offered choice exists on the same carrier.
  static List<SyllableEntry> pairedEntries(
    LessonSpec spec,
    List<SyllableEntry> pool,
    Map<SyllableKey, SyllableEntry> catalogByKey,
  ) {
    if (!spec.pairedChoicesRequired) return pool;
    final poolSet = {for (final e in pool) e.key};
    final result = <SyllableEntry>[];
    for (final entry in pool) {
      final choices = choicesForEntry(spec, entry);
      var allPresent = true;
      for (final c in choices) {
        final key = candidateKeyForChoice(spec, entry, c);
        if (key == null ||
            (!poolSet.contains(key) && !catalogByKey.containsKey(key))) {
          allPresent = false;
          break;
        }
      }
      if (allPresent) {
        result.add(entry);
      }
    }
    return result;
  }

  /// Determines which choice group applies for a sampled [entry] (handles `u6_l2`).
  static List<String> choicesForEntry(LessonSpec spec, SyllableEntry entry) {
    final groups = spec.choiceGroups;
    if (groups != null && groups.isNotEmpty) {
      final val = componentValue(spec, entry);
      for (final group in groups) {
        if (!group.contains(val)) continue;
        // Pick the group matching the carrier coda for `yu` (`""` -> oe; `-n/-t` -> eo).
        if (spec.id == 'u6_l2_yu_oe_eo') {
          if (entry.coda.isEmpty && group.contains('oe')) return group;
          if (entry.coda.isNotEmpty && group.contains('eo')) return group;
        } else {
          return group;
        }
      }
    }
    return spec.choices;
  }

  /// Extracts the contrasted target string from [entry] under [spec].
  static String componentValue(LessonSpec spec, SyllableEntry entry) {
    switch (spec.targetComponent) {
      case ComponentType.initial:
        return entry.initial;
      case ComponentType.nucleus:
        return entry.nucleus;
      case ComponentType.coda:
        return entry.coda;
      case ComponentType.tone:
        return entry.tone.toString();
      case null:
        return entry.base;
    }
  }

  /// Builds the hypothetical [SyllableKey] obtained by swapping [entry]'s target with [choice].
  static SyllableKey? candidateKeyForChoice(
    LessonSpec spec,
    SyllableEntry entry,
    String choice,
  ) {
    switch (spec.targetComponent) {
      case ComponentType.initial:
        return SyllableKey(
          initial: choice,
          nucleus: entry.nucleus,
          coda: entry.coda,
          tone: entry.tone,
        );
      case ComponentType.nucleus:
        return SyllableKey(
          initial: entry.initial,
          nucleus: choice,
          coda: entry.coda,
          tone: entry.tone,
        );
      case ComponentType.coda:
        return SyllableKey(
          initial: entry.initial,
          nucleus: entry.nucleus,
          coda: choice,
          tone: entry.tone,
        );
      case ComponentType.tone:
        final t = int.tryParse(choice);
        if (t == null) return null;
        return SyllableKey(
          initial: entry.initial,
          nucleus: entry.nucleus,
          coda: entry.coda,
          tone: t,
        );
      case null:
        // Whole-syllable contrast (`u6_l4_syllabic_nasals`).
        if (choice == 'm' || choice == 'ng') {
          return SyllableKey(initial: '', nucleus: '', coda: choice, tone: entry.tone);
        }
        if (choice == 'hm') {
          return SyllableKey(initial: 'h', nucleus: '', coda: 'm', tone: entry.tone);
        }
        if (choice == 'hng') {
          return SyllableKey(initial: 'h', nucleus: '', coda: 'ng', tone: entry.tone);
        }
        return null;
    }
  }

  /// Human-readable label/subtitle helpers for choice cards.
  static ChoiceOption buildChoiceOption({
    required LessonSpec spec,
    required SyllableEntry target,
    required String value,
    required Map<SyllableKey, SyllableEntry> catalogByKey,
  }) {
    final key = candidateKeyForChoice(spec, target, value);
    final attested = key == null ? null : catalogByKey[key];
    final tone = spec.targetComponent == ComponentType.tone
        ? int.tryParse(value)
        : null;
    final isChecked = _checkedCodas.contains(target.coda);

    if (spec.targetComponent == ComponentType.tone && tone != null) {
      return ChoiceOption(
        value: value,
        label: plainToneLabel(tone),
        tone: tone,
        syllableEntry: attested,
        isCheckedTone: isChecked,
      );
    }

    String display;
    String? subtitle;
    switch (spec.targetComponent) {
      case ComponentType.initial:
        display = value.isEmpty ? ComponentType.noneLabel : value;
        subtitle = attested?.syllable;
      case ComponentType.nucleus:
        display = value;
        subtitle = attested?.syllable;
      case ComponentType.coda:
        display = value.isEmpty ? ComponentType.noneLabel : '-$value';
        subtitle = attested?.syllable;
      case ComponentType.tone:
      case null:
        display = value;
        subtitle = attested?.syllable;
    }

    return ChoiceOption(
      value: value,
      label: display,
      subtitle: subtitle,
      tone: tone,
      syllableEntry: attested,
      isCheckedTone: isChecked,
    );
  }
}
