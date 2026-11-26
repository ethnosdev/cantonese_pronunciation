import 'lesson_spec.dart';
import 'syllable_models.dart';

/// Complete 7-unit, 28-lesson beginner curriculum verified against `syllables.json`.
class Curriculum {
  const Curriculum._();

  /// Beginner-friendly tone names (Chao digits hidden in beginner path).
  static const Map<int, String> tonePlainNames = {
    1: 'High Flat',
    2: 'High Rising',
    3: 'Mid Flat',
    4: 'Low Falling',
    5: 'Low Rising',
    6: 'Low Flat',
  };

  /// Formatted plain label for beginner tone choice buttons (`1 · High Flat`).
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
      title: 'First Tones',
      subtitle: 'Hear high, rising, mid, and low pitch shapes',
    ),
    const UnitSpec(
      id: 'unit_2',
      number: 2,
      title: 'Soft vs. Air-Puff Starts',
      subtitle: 'Tell gentle b/d/g apart from air-puff p/t/k',
    ),
    const UnitSpec(
      id: 'unit_3',
      number: 3,
      title: 'All Six Tones',
      subtitle: 'Separate high vs. low rising and flat tones',
    ),
    const UnitSpec(
      id: 'unit_4',
      number: 4,
      title: 'Remaining Starts',
      subtitle: 'Master n/l, sharp starts z/c/s/j, gw/kw/w, and ng vs. None',
    ),
    const UnitSpec(
      id: 'unit_5',
      number: 5,
      title: 'Open Vowels & Basic Endings',
      subtitle: 'Hear open vowels, glides (-i, -u), and nasal endings (-m, -n, -ng)',
    ),
    const UnitSpec(
      id: 'unit_6',
      number: 6,
      title: 'Vowel Contrasts, Clipped Endings & Hums',
      subtitle: 'Long aa vs. short a, yu/oe/eo, clipped -p/-t/-k, and hummed syllables',
    ),
    const UnitSpec(
      id: 'unit_7',
      number: 7,
      title: 'Multi-Slot Assembly to Full Mastery',
      subtitle: 'Combine Start, Vowel, Ending, and Tone across all 42 keys',
    ),
  ];

  static final List<LessonSpec> lessons = [
    // ---------------- Unit 1: First Tones ----------------
    LessonSpec(
      id: 'u1_l1_high_vs_low',
      unitId: 'unit_1',
      numberLabel: '1.1',
      title: 'High Flat (1) vs. Low Falling (4)',
      cue: 'Cantonese words change meaning with voice pitch. Compare high flat (1) with low falling (4).',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      differentProperty: DifferentProperty.tone,
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
            label: '1 · High Flat',
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
        sameDifferentPrompt: 'Same Tone?',
        differentProperty: DifferentProperty.tone,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u1_l1_high_vs_low',
          targetType: 'tone',
          targetValue: '1',
          displayLabel: 'Tone 1 · High Flat',
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
      cue: 'Tone 2 climbs upward like asking a quick question. Contrast it against flat 1 and falling 4.',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      differentProperty: DifferentProperty.tone,
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
            label: '1 · High Flat',
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
        sameDifferentPrompt: 'Same Tone?',
        differentProperty: DifferentProperty.tone,
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
      title: 'Mid Flat (3)',
      cue: 'Tone 3 stays flat in the middle of your voice—lower than 1, and without the drop of 4.',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      differentProperty: DifferentProperty.tone,
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
            label: '1 · High Flat',
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
            label: '3 · Mid Flat',
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
          displayLabel: 'Tone 3 · Mid Flat',
        ),
      ],
    ),
    LessonSpec(
      id: 'u1_l4_four_tone_check',
      unitId: 'unit_1',
      numberLabel: '1.4',
      title: 'Four Tones Without Curves',
      cue: 'Listen carefully—pitch curves are now hidden on the buttons so your ear takes over.',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      differentProperty: DifferentProperty.tone,
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

    // ---------------- Unit 2: Soft vs. Air-Puff Starts ----------------
    LessonSpec(
      id: 'u2_l1_b_vs_p',
      unitId: 'unit_2',
      numberLabel: '2.1',
      title: 'Soft b vs. Air-Puff p',
      cue: 'In Cantonese, both b and p are voiceless—p releases a strong puff of air while b does not.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      differentProperty: DifferentProperty.initial,
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
            label: 'b · Soft',
            hint: 'Gentle lip release, no puff of air',
            preferredSyllable: 'baa1',
          ),
          HearAndCompareItem(
            value: 'p',
            label: 'p · Air-Puff',
            hint: 'Sharp burst of breath',
            preferredSyllable: 'paa1',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same Start?',
        differentProperty: DifferentProperty.initial,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u2_l1_b_vs_p',
          targetType: 'initial',
          targetValue: 'b',
          displayLabel: 'Start b (soft)',
        ),
        ContrastSkill(
          lessonId: 'u2_l1_b_vs_p',
          targetType: 'initial',
          targetValue: 'p',
          displayLabel: 'Start p (air-puff)',
        ),
      ],
    ),
    LessonSpec(
      id: 'u2_l2_d_vs_t',
      unitId: 'unit_2',
      numberLabel: '2.2',
      title: 'Soft d vs. Air-Puff t',
      cue: 'Same air-puff contrast at the tongue tip: soft d has no breath burst, t pushes air out.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      differentProperty: DifferentProperty.initial,
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
            label: 'd · Soft',
            hint: 'Crisp tongue tap, no air puff',
            preferredSyllable: 'daa1',
          ),
          HearAndCompareItem(
            value: 't',
            label: 't · Air-Puff',
            hint: 'Releases a puff of air',
            preferredSyllable: 'taa1',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same Start?',
        differentProperty: DifferentProperty.initial,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u2_l2_d_vs_t',
          targetType: 'initial',
          targetValue: 'd',
          displayLabel: 'Start d (soft)',
        ),
        ContrastSkill(
          lessonId: 'u2_l2_d_vs_t',
          targetType: 'initial',
          targetValue: 't',
          displayLabel: 'Start t (air-puff)',
        ),
      ],
    ),
    LessonSpec(
      id: 'u2_l3_g_vs_k',
      unitId: 'unit_2',
      numberLabel: '2.3',
      title: 'Soft g vs. Air-Puff k',
      cue: 'Contrast the back-of-mouth stops: soft g stays clean, while k pushes out a breath burst.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      differentProperty: DifferentProperty.initial,
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
            label: 'g · Soft',
            hint: 'Clean release at back of tongue',
            preferredSyllable: 'gaa1',
          ),
          HearAndCompareItem(
            value: 'k',
            label: 'k · Air-Puff',
            hint: 'Strong puff of breath',
            preferredSyllable: 'kaa1',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same Start?',
        differentProperty: DifferentProperty.initial,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u2_l3_g_vs_k',
          targetType: 'initial',
          targetValue: 'g',
          displayLabel: 'Start g (soft)',
        ),
        ContrastSkill(
          lessonId: 'u2_l3_g_vs_k',
          targetType: 'initial',
          targetValue: 'k',
          displayLabel: 'Start k (air-puff)',
        ),
      ],
    ),
    LessonSpec(
      id: 'u2_l4_stops_review',
      unitId: 'unit_2',
      numberLabel: '2.4',
      title: 'All Six Stop Starts',
      cue: 'Pick the Start you hear across all six soft and air-puff stops (b, p, d, t, g, k).',
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
      cue: 'Mix tones from Unit 1 with soft and air-puff starts from Unit 2.',
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
      title: 'High Rising (2) vs. Low Rising (5)',
      cue: 'Both tones rise, but 2 climbs much higher than gentle low-rising 5.',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      differentProperty: DifferentProperty.tone,
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
        sameDifferentPrompt: 'Same Tone?',
        differentProperty: DifferentProperty.tone,
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
      title: 'Mid Flat (3) vs. Low Flat (6)',
      cue: 'Tone 6 sits flat and low, without sinking down like Tone 4.',
      poolTier: DatasetTier.pri0And1,
      targetComponent: ComponentType.tone,
      differentProperty: DifferentProperty.tone,
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
            label: '3 · Mid Flat',
            hint: 'Steady middle pitch',
            preferredSyllable: 'si3',
            tone: 3,
          ),
          HearAndCompareItem(
            value: '6',
            label: '6 · Low Flat',
            hint: 'Steady low pitch',
            preferredSyllable: 'si6',
            tone: 6,
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same Tone?',
        differentProperty: DifferentProperty.tone,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u3_l2_level_3_vs_6',
          targetType: 'tone',
          targetValue: '6',
          displayLabel: 'Tone 6 · Low Flat',
        ),
      ],
    ),
    LessonSpec(
      id: 'u3_l3_low_tones_mix',
      unitId: 'unit_3',
      numberLabel: '3.3',
      title: 'Mid & Low Tones (2, 3, 4, 5, 6)',
      cue: 'Tell apart the five closely spaced mid and low tones without button curves.',
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
      title: 'All Six Tones (1–6)',
      cue: 'Unit 3 check: distinguish all six Cantonese tones across open and nasal syllables.',
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
      cue: 'Review all six tones alongside soft and air-puff starts.',
      poolTier: DatasetTier.pri0And1,
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      poolPredicate: (e) => e.nucleus.isNotEmpty,
      cumulativeReviewUpToUnit: 3,
    ),

    // ---------------- Unit 4: Remaining Starts ----------------
    LessonSpec(
      id: 'u4_l1_n_vs_l',
      unitId: 'unit_4',
      numberLabel: '4.1',
      title: 'Nasal n vs. Clear l',
      cue: 'Start n hums gently through the nose before opening; l lets air flow around the tongue.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      differentProperty: DifferentProperty.initial,
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
            hint: 'Buzz through nose first',
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
        sameDifferentPrompt: 'Same Start?',
        differentProperty: DifferentProperty.initial,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u4_l1_n_vs_l',
          targetType: 'initial',
          targetValue: 'n',
          displayLabel: 'Start n (nasal)',
        ),
        ContrastSkill(
          lessonId: 'u4_l1_n_vs_l',
          targetType: 'initial',
          targetValue: 'l',
          displayLabel: 'Start l (clear)',
        ),
      ],
    ),
    LessonSpec(
      id: 'u4_l2_m_f_h',
      unitId: 'unit_4',
      numberLabel: '4.2',
      title: 'Lip & Breath Starts (m, f, h)',
      cue: 'Hear lip-nasal m alongside breathy f and h.',
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
            hint: 'Hum on the lips',
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
            hint: 'Soft breathy h',
            preferredSyllable: 'haa1',
          ),
        ],
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u4_l2_m_f_h',
          targetType: 'initial',
          targetValue: 'm',
          displayLabel: 'Start m',
        ),
        ContrastSkill(
          lessonId: 'u4_l2_m_f_h',
          targetType: 'initial',
          targetValue: 'f',
          displayLabel: 'Start f',
        ),
        ContrastSkill(
          lessonId: 'u4_l2_m_f_h',
          targetType: 'initial',
          targetValue: 'h',
          displayLabel: 'Start h',
        ),
      ],
    ),
    LessonSpec(
      id: 'u4_l3_z_c_s_j',
      unitId: 'unit_4',
      numberLabel: '4.3',
      title: 'Sharp Starts (z, c, s, j)',
      cue: 'Ear anchors: z sounds like ds in kids, c adds a sharp ts air puff, and j sounds like y in yes.',
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
            label: 'z · Soft ds',
            hint: 'No air puff (ds)',
            preferredSyllable: 'zaa1',
          ),
          HearAndCompareItem(
            value: 'c',
            label: 'c · Air-puff ts',
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
          displayLabel: 'Start z (ds)',
        ),
        ContrastSkill(
          lessonId: 'u4_l3_z_c_s_j',
          targetType: 'initial',
          targetValue: 'c',
          displayLabel: 'Start c (ts)',
        ),
        ContrastSkill(
          lessonId: 'u4_l3_z_c_s_j',
          targetType: 'initial',
          targetValue: 's',
          displayLabel: 'Start s',
        ),
        ContrastSkill(
          lessonId: 'u4_l3_z_c_s_j',
          targetType: 'initial',
          targetValue: 'j',
          displayLabel: 'Start j (y)',
        ),
      ],
    ),
    LessonSpec(
      id: 'u4_l4_gw_kw_w',
      unitId: 'unit_4',
      numberLabel: '4.4',
      title: 'Rounded gw, kw, w (vs. g, k)',
      cue: 'Round your lips on gw and kw—hear how that w-glide sets them apart from plain g, k, and w.',
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
            hint: 'Unrounded soft stop',
            preferredSyllable: 'gaa1',
          ),
          HearAndCompareItem(
            value: 'k',
            label: 'k · Plain puff',
            hint: 'Unrounded air puff',
            preferredSyllable: 'kaa1',
          ),
          HearAndCompareItem(
            value: 'gw',
            label: 'gw · Rounded',
            hint: 'Soft g + rounded lips',
            preferredSyllable: 'gwaa1',
          ),
          HearAndCompareItem(
            value: 'kw',
            label: 'kw · Rounded puff',
            hint: 'Air-puff k + rounded lips',
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
          displayLabel: 'Start gw',
        ),
        ContrastSkill(
          lessonId: 'u4_l4_gw_kw_w',
          targetType: 'initial',
          targetValue: 'kw',
          displayLabel: 'Start kw',
        ),
        ContrastSkill(
          lessonId: 'u4_l4_gw_kw_w',
          targetType: 'initial',
          targetValue: 'w',
          displayLabel: 'Start w',
        ),
      ],
    ),
    LessonSpec(
      id: 'u4_l5_ng_vs_none',
      unitId: 'unit_4',
      numberLabel: '4.5',
      title: 'Back-Nasal ng vs. None',
      cue: 'Hear when a syllable starts with a back-throat ng hum versus starting cleanly with None.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.initial,
      differentProperty: DifferentProperty.initial,
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
            label: 'None · Open start',
            hint: 'Begins directly on the vowel',
            preferredSyllable: 'aa4',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same Start?',
        differentProperty: DifferentProperty.initial,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u4_l5_ng_vs_none',
          targetType: 'initial',
          targetValue: 'ng',
          displayLabel: 'Start ng',
        ),
        ContrastSkill(
          lessonId: 'u4_l5_ng_vs_none',
          targetType: 'initial',
          targetValue: '',
          displayLabel: 'Start None',
        ),
      ],
    ),
    LessonSpec(
      id: 'u4_review',
      unitId: 'unit_4',
      numberLabel: 'R4',
      title: 'Units 1–4 Review',
      cue: 'Mix all six tones with every start consonant learned so far.',
      poolTier: DatasetTier.pri0And1,
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      poolPredicate: (e) => e.nucleus.isNotEmpty,
      cumulativeReviewUpToUnit: 4,
    ),

    // ---------------- Unit 5: Open Vowels & Basic Endings ----------------
    LessonSpec(
      id: 'u5_l1_open_vowels',
      unitId: 'unit_5',
      numberLabel: '5.1',
      title: 'Five Open Vowels (aa, e, i, o, u)',
      cue: 'Master the five open vowels (`aa` sounds like "ah"). Short `a` only appears with endings later.',
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
      title: 'Glide Endings (None, -i, -u)',
      cue: 'Listen for whether the vowel stays open (None) or glides toward -i or -u at the end.',
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
          displayLabel: 'Ending None (open)',
        ),
        ContrastSkill(
          lessonId: 'u5_l2_glide_endings',
          targetType: 'coda',
          targetValue: 'i',
          displayLabel: 'Ending -i',
        ),
        ContrastSkill(
          lessonId: 'u5_l2_glide_endings',
          targetType: 'coda',
          targetValue: 'u',
          displayLabel: 'Ending -u',
        ),
      ],
    ),
    LessonSpec(
      id: 'u5_l3_nasal_endings',
      unitId: 'unit_5',
      numberLabel: '5.3',
      title: 'Nasal Endings (-m, -n, -ng)',
      cue: 'Hear where the hum closes: -m shuts the lips, -n taps the tongue tip, -ng closes at the back.',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.coda,
      differentProperty: DifferentProperty.coda,
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
            hint: 'Open mouth, back nasal hum',
            preferredSyllable: 'saang1',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same Ending?',
        differentProperty: DifferentProperty.coda,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u5_l3_nasal_endings',
          targetType: 'coda',
          targetValue: 'm',
          displayLabel: 'Ending -m',
        ),
        ContrastSkill(
          lessonId: 'u5_l3_nasal_endings',
          targetType: 'coda',
          targetValue: 'n',
          displayLabel: 'Ending -n',
        ),
        ContrastSkill(
          lessonId: 'u5_l3_nasal_endings',
          targetType: 'coda',
          targetValue: 'ng',
          displayLabel: 'Ending -ng',
        ),
      ],
    ),
    LessonSpec(
      id: 'u5_review',
      unitId: 'unit_5',
      numberLabel: 'R5',
      title: 'Units 1–5 Review',
      cue: 'Review open vowels, glides, and nasal endings alongside tones and starts.',
      poolTier: DatasetTier.pri0And1,
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      poolPredicate: (e) => e.nucleus.isNotEmpty,
      cumulativeReviewUpToUnit: 5,
    ),

    // ---------------- Unit 6: Contrasts, Clipped Endings & Hums ----------------
    LessonSpec(
      id: 'u6_l1_aa_vs_a',
      unitId: 'unit_6',
      numberLabel: '6.1',
      title: 'Long aa vs. Short a (With Endings)',
      cue: 'Long aa stretches clearly before the ending (saam); short a snaps quickly into the ending (sam).',
      poolTier: DatasetTier.pri0,
      targetComponent: ComponentType.nucleus,
      differentProperty: DifferentProperty.nucleus,
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
            hint: 'Held wide "ah" (saam1)',
            preferredSyllable: 'saam1',
          ),
          HearAndCompareItem(
            value: 'a',
            label: 'a · Short',
            hint: 'Quick central "uh" (sam1)',
            preferredSyllable: 'sam1',
          ),
        ],
        sameDifferentCount: 2,
        sameDifferentPrompt: 'Same Vowel?',
        differentProperty: DifferentProperty.nucleus,
      ),
      seedSkills: const [
        ContrastSkill(
          lessonId: 'u6_l1_aa_vs_a',
          targetType: 'nucleus',
          targetValue: 'a',
          displayLabel: 'Vowel a (short)',
        ),
      ],
    ),
    LessonSpec(
      id: 'u6_l2_yu_oe_eo',
      unitId: 'unit_6',
      numberLabel: '6.2',
      title: 'Rounded Front Vowels (yu, oe, eo)',
      cue: 'Keep lips rounded while contrasting high yu against open oe (syu1/soe1) and short eo before -n/-t (syun1/seon1).',
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
            hint: 'Say "ee" with rounded lips (syu1)',
            preferredSyllable: 'syu1',
          ),
          HearAndCompareItem(
            value: 'oe',
            label: 'oe · Open rounded',
            hint: 'Open rounded mid sound (soe1 / soeng1)',
            preferredSyllable: 'soe1',
          ),
          HearAndCompareItem(
            value: 'eo',
            label: 'eo · Closed rounded',
            hint: 'Tight short rounded vowel before -n/-t (seon1)',
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
      title: 'Clipped Endings (-p, -t, -k)',
      cue: 'Mouth snaps shut without popping air out—always short in tones 1, 3, or 6.',
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
            label: '-p · Clipped lips',
            hint: 'Lips press shut quickly (saap3)',
            preferredSyllable: 'saap3',
            tone: 3,
            isCheckedTone: true,
          ),
          HearAndCompareItem(
            value: 't',
            label: '-t · Clipped tongue',
            hint: 'Tongue stops air cleanly (saat3)',
            preferredSyllable: 'saat3',
            tone: 3,
            isCheckedTone: true,
          ),
          HearAndCompareItem(
            value: 'k',
            label: '-k · Clipped throat',
            hint: 'Back tongue catches abruptly (saak3)',
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
          displayLabel: 'Ending -p',
        ),
        ContrastSkill(
          lessonId: 'u6_l3_checked_stops',
          targetType: 'coda',
          targetValue: 't',
          displayLabel: 'Ending -t',
        ),
        ContrastSkill(
          lessonId: 'u6_l3_checked_stops',
          targetType: 'coda',
          targetValue: 'k',
          displayLabel: 'Ending -k',
        ),
      ],
    ),
    LessonSpec(
      id: 'u6_l4_syllabic_nasals',
      unitId: 'unit_6',
      numberLabel: '6.4',
      title: 'Hummed Syllables (m, hm, ng, hng)',
      cue: 'Four standalone words hum directly with no vowel (Start: None or h + Ending: m or ng).',
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
            label: 'm · Lip hum',
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
            label: 'ng · Back hum',
            hint: 'Throat nasal hum alone',
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
          displayLabel: 'Hummed m',
        ),
        ContrastSkill(
          lessonId: 'u6_l4_syllabic_nasals',
          targetType: 'syllable',
          targetValue: 'hm',
          displayLabel: 'Hummed hm',
        ),
        ContrastSkill(
          lessonId: 'u6_l4_syllabic_nasals',
          targetType: 'syllable',
          targetValue: 'ng',
          displayLabel: 'Hummed ng',
        ),
        ContrastSkill(
          lessonId: 'u6_l4_syllabic_nasals',
          targetType: 'syllable',
          targetValue: 'hng',
          displayLabel: 'Hummed hng',
        ),
      ],
    ),
    LessonSpec(
      id: 'u6_review',
      unitId: 'unit_6',
      numberLabel: 'R6',
      title: 'Units 1–6 Review',
      cue: 'Full contrast review across all tones, starts, vowels, endings, and hums.',
      poolTier: DatasetTier.pri0And1,
      format: ExerciseFormat.choiceCards,
      coreCount: 24,
      poolPredicate: (_) => true,
      cumulativeReviewUpToUnit: 6,
    ),

    // ---------------- Unit 7: Multi-Slot Assembly to Mastery ----------------
    LessonSpec(
      id: 'u7_l1_start_plus_tone',
      unitId: 'unit_7',
      numberLabel: '7.1',
      title: 'Start + Tone Assembly',
      cue: 'Vowel and Ending are filled in—pick the matching Start (leave blank for None) and Tone.',
      poolTier: DatasetTier.pri0,
      format: ExerciseFormat.slotAssembly,
      coreCount: 24,
      poolPredicate: (e) => e.nucleus.isNotEmpty,
      slotMask: const SlotMask(
        lockedComponents: {ComponentType.nucleus, ComponentType.coda},
        visibleComponents: {ComponentType.initial, ComponentType.tone},
        isGuided: true,
      ),
    ),
    LessonSpec(
      id: 'u7_l2_vowel_ending_tone',
      unitId: 'unit_7',
      numberLabel: '7.2',
      title: 'Vowel + Ending + Tone',
      cue: 'Start is filled in—build Vowel, Ending (leave blank for None), and Tone.',
      poolTier: DatasetTier.pri0,
      format: ExerciseFormat.slotAssembly,
      coreCount: 24,
      poolPredicate: (e) => e.nucleus.isNotEmpty,
      slotMask: const SlotMask(
        lockedComponents: {ComponentType.initial},
        visibleComponents: {
          ComponentType.nucleus,
          ComponentType.coda,
          ComponentType.tone,
        },
        isGuided: true,
      ),
    ),
    LessonSpec(
      id: 'u7_l3_guided_42_keys',
      unitId: 'unit_7',
      numberLabel: '7.3',
      title: 'Guided 4-Slot Transcription',
      cue: 'Assemble all four parts with invalid combinations dimmed as a guide.',
      poolTier: DatasetTier.pri0,
      format: ExerciseFormat.slotAssembly,
      coreCount: 24,
      poolPredicate: (_) => true,
      slotMask: const SlotMask(
        lockedComponents: {},
        visibleComponents: {
          ComponentType.initial,
          ComponentType.nucleus,
          ComponentType.coda,
          ComponentType.tone,
        },
        isGuided: true,
      ),
    ),
    LessonSpec(
      id: 'u7_l4_open_42_keys',
      unitId: 'unit_7',
      numberLabel: '7.4',
      title: 'Unassisted 42-Key Mastery',
      cue: 'Final mastery check: transcribe every syllable from scratch across all 42 keys.',
      poolTier: DatasetTier.pri0,
      format: ExerciseFormat.slotAssembly,
      coreCount: 28,
      poolPredicate: (_) => true,
      slotMask: const SlotMask(
        lockedComponents: {},
        visibleComponents: {
          ComponentType.initial,
          ComponentType.nucleus,
          ComponentType.coda,
          ComponentType.tone,
        },
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
        display = value.isEmpty ? 'None' : value;
        subtitle = attested?.syllable;
      case ComponentType.nucleus:
        display = value;
        subtitle = attested?.syllable;
      case ComponentType.coda:
        display = value.isEmpty ? 'None' : '-$value';
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
