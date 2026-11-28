import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cantonese_pronunciation/core/curriculum.dart';
import 'package:cantonese_pronunciation/core/lesson_session.dart';
import 'package:cantonese_pronunciation/core/lesson_spec.dart';
import 'package:cantonese_pronunciation/core/syllable_models.dart';
import 'package:flutter_test/flutter_test.dart';

List<SyllableEntry> _buildRichFixtureCatalog() {
  final entries = <SyllableEntry>[];
  void add(
    String i,
    String n,
    String c,
    List<int> tones, {
    int priority = 0,
  }) {
    for (final t in tones) {
      final syl = '$i$n$c$t';
      entries.add(
        SyllableEntry(
          syllable: syl,
          path: '$n/$t/$syl.opus',
          initial: i,
          nucleus: n,
          coda: c,
          tone: t,
          initialGroup: 0,
          priority: priority,
        ),
      );
    }
  }

  // Transparent pri01 bases across tones 1..6.
  for (final base in const ['baa', 'daa', 'saa', 'si', 'laa']) {
    final i = base[0];
    final n = base.substring(1);
    add(i, n, '', [1, 2, 3, 4, 5, 6], priority: 1);
  }
  // Stops & other initials in pri0.
  for (final i in const ['b', 'p', 'd', 't', 'g', 'k', 'n', 'l', 'm', 'f', 'h', 'z', 'c', 's', 'j', 'gw', 'kw', 'w', 'ng', '']) {
    add(i, 'aa', '', [1, 3, 4], priority: 0);
  }
  // Open vowels across {b, l, g} in pri01.
  for (final i in const ['b', 'l', 'g']) {
    for (final n in const ['aa', 'e', 'i', 'o', 'u']) {
      add(i, n, '', [1, 2, 3], priority: 1);
    }
  }
  // Glide & nasal endings in pri0.
  for (final c in const ['', 'i', 'u', 'm', 'n', 'ng']) {
    add('h', 'aa', c, [1], priority: 0);
    add('s', 'aa', c, [1, 3], priority: 0);
  }
  // Long aa vs short a before endings.
  for (final n in const ['aa', 'a']) {
    add('s', n, 'm', [1, 3], priority: 0);
  }
  // Rounded vowels yu/oe open on z/s (pri01) and yu/eo on -n/-t (pri0).
  for (final i in const ['z', 's']) {
    add(i, 'yu', '', [1, 4], priority: 1);
    add(i, 'oe', '', [1, 4], priority: 1);
  }
  for (final c in const ['n', 't']) {
    final tones = c == 't' ? [1, 3, 6] : [1, 4];
    add('s', 'yu', c, tones, priority: 0);
    add('s', 'eo', c, tones, priority: 0);
  }
  // Checked stops -p/-t/-k (plus artificial pri1 checked tone 2 to test u3_l4 guard).
  for (final c in const ['p', 't', 'k']) {
    add('s', 'aa', c, [1, 3, 6], priority: 0);
    add('s', 'aa', c, [2], priority: 1);
  }
  // Syllabic nasals.
  add('', '', 'm', [4], priority: 0);
  add('h', '', 'm', [1], priority: 1);
  add('', '', 'ng', [4], priority: 0);
  add('h', '', 'ng', [1], priority: 1);

  return entries;
}

void main() {
  test('curriculum defines 7 units, 28 lessons, 5 cumulative reviews, and 48 contrast skills', () {
    expect(Curriculum.units.length, 7);
    expect(Curriculum.standardLessons.length, 28);
    expect(Curriculum.cumulativeReviews.length, 5);
    expect(Curriculum.lessons.length, 33);
    expect(Curriculum.transparentBases.length, 20);
    for (final lesson in Curriculum.lessons) {
      expect(lesson.coreCount, greaterThanOrEqualTo(20), reason: lesson.id);
    }

    expect(Curriculum.lessons.first.numberLabel, '1.1');
    expect(Curriculum.lessons.first.id, 'u1_l1_high_vs_low');
    expect(Curriculum.lessons.last.numberLabel, '7.4');
    expect(Curriculum.lessons.last.id, 'u7_l4_open_42_keys');
    expect(Curriculum.nextLessonIdAfter('u2_l4_stops_review'), 'u2_review');
    expect(Curriculum.nextLessonIdAfter('u2_review'), 'u3_l1_rising_2_vs_5');
    expect(Curriculum.nextLessonIdAfter('u6_l4_syllabic_nasals'), 'u6_review');
    expect(Curriculum.nextLessonIdAfter('u6_review'), 'u7_l1_start_plus_tone');

    expect(Curriculum.allSeedSkills.length, 48);
    final uniqueSkillIds = Curriculum.allSeedSkills.map((s) => s.skillId).toSet();
    expect(uniqueSkillIds.length, 48);

    // Check/assembly lessons seed zero new SRS rows.
    for (final id in const [
      'u1_l4_four_tone_check',
      'u2_l4_stops_review',
      'u3_l3_low_tones_mix',
      'u3_l4_six_tone_check',
      'u7_l1_start_plus_tone',
      'u7_l2_vowel_ending_tone',
      'u7_l3_guided_42_keys',
      'u7_l4_open_42_keys',
    ]) {
      expect(Curriculum.lessonById(id)!.seedSkills, isEmpty);
    }

    // u6_l4 seeds 4 syllable skills.
    final u6L4 = Curriculum.lessonById('u6_l4_syllabic_nasals')!;
    expect(
      u6L4.seedSkills.map((s) => s.skillId),
      equals([
        'u6_l4_syllabic_nasals:syllable:m',
        'u6_l4_syllabic_nasals:syllable:hm',
        'u6_l4_syllabic_nasals:syllable:ng',
        'u6_l4_syllabic_nasals:syllable:hng',
      ]),
    );
  });

  test('pins immutable keys and enforces Phase 1 and Phase 2 terminology and no-IPA/no-Chao rules', () {
    expect(
      Curriculum.units.map((u) => u.id),
      equals([
        'unit_1',
        'unit_2',
        'unit_3',
        'unit_4',
        'unit_5',
        'unit_6',
        'unit_7',
      ]),
    );
    expect(ComponentType.values.map((c) => c.name), [
      'initial',
      'nucleus',
      'coda',
      'tone',
    ]);
    expect(FocusFilter.fromId('initial:zeroNgH').id, 'initial:zeroNgH');
    expect(FocusFilter.fromId('initial:zeroNgH').label, 'Initials: None / ng / h');

    final ipaRe = RegExp(r'[\u014B\u0153\u0250-\u02FF\u0300-\u036F]|IPA \[');
    final chaoRe = RegExp(r'\b(55|35|33|21|23|22)\b');
    final retiredRe = RegExp(
      r'(Flat|Soft|Air-[Pp]uff|Open start|Hums|`)',
      caseSensitive: true,
    );
    final toneBarsOrCombiningRe = RegExp(r'[\u02E5-\u02E9\u0300-\u036F]');
    final duplicateParenRe = RegExp(r'\([a-z]+[1-6][^)]*\).*\([a-z]+[1-6]');

    for (final toneName in Curriculum.tonePlainNames.values) {
      expect(ipaRe.hasMatch(toneName), isFalse, reason: toneName);
      expect(chaoRe.hasMatch(toneName), isFalse, reason: toneName);
      expect(retiredRe.hasMatch(toneName), isFalse, reason: toneName);
    }

    for (final unit in Curriculum.units) {
      expect(ipaRe.hasMatch(unit.title), isFalse, reason: unit.id);
      expect(chaoRe.hasMatch(unit.title), isFalse, reason: unit.id);
      expect(retiredRe.hasMatch(unit.title), isFalse, reason: unit.id);
    }

    for (final lesson in Curriculum.lessons) {
      expect(ipaRe.hasMatch(lesson.title), isFalse, reason: lesson.id);
      expect(chaoRe.hasMatch(lesson.title), isFalse, reason: lesson.id);
      expect(retiredRe.hasMatch(lesson.title), isFalse, reason: lesson.id);

      expect(lesson.introSummary.trim(), isNotEmpty, reason: lesson.id);
      expect(
        ipaRe.hasMatch(lesson.introSummary),
        isFalse,
        reason: '${lesson.id} introSummary',
      );
      expect(
        chaoRe.hasMatch(lesson.introSummary),
        isFalse,
        reason: '${lesson.id} introSummary',
      );
      expect(
        retiredRe.hasMatch(lesson.introSummary),
        isFalse,
        reason: '${lesson.id} introSummary',
      );

      if (lesson.format == ExerciseFormat.slotAssembly) {
        expect(
          lesson.trialPrompt,
          isNotNull,
          reason: '${lesson.id} requires trialPrompt',
        );
        expect(
          lesson.trialPrompt!.trim(),
          isNotEmpty,
          reason: '${lesson.id} trialPrompt non-empty',
        );
      }

      if (lesson.trialPrompt != null) {
        expect(
          ipaRe.hasMatch(lesson.trialPrompt!),
          isFalse,
          reason: '${lesson.id} trialPrompt',
        );
        expect(
          chaoRe.hasMatch(lesson.trialPrompt!),
          isFalse,
          reason: '${lesson.id} trialPrompt',
        );
        expect(
          retiredRe.hasMatch(lesson.trialPrompt!),
          isFalse,
          reason: '${lesson.id} trialPrompt',
        );
      }

      if (lesson.phoneticsNote != null) {
        expect(
          toneBarsOrCombiningRe.hasMatch(lesson.phoneticsNote!),
          isFalse,
          reason: '${lesson.id} phoneticsNote',
        );
      }

      final warmup = lesson.warmup;
      if (warmup != null) {
        if (warmup.sameDifferentPrompt != null) {
          expect(
            ipaRe.hasMatch(warmup.sameDifferentPrompt!),
            isFalse,
            reason: lesson.id,
          );
          expect(
            chaoRe.hasMatch(warmup.sameDifferentPrompt!),
            isFalse,
            reason: lesson.id,
          );
        }
        for (final item in warmup.hearAndCompareItems) {
          expect(ipaRe.hasMatch(item.label), isFalse, reason: item.label);
          expect(chaoRe.hasMatch(item.label), isFalse, reason: item.label);
          expect(retiredRe.hasMatch(item.label), isFalse, reason: item.label);
          expect(ipaRe.hasMatch(item.hint), isFalse, reason: item.hint);
          expect(chaoRe.hasMatch(item.hint), isFalse, reason: item.hint);
          expect(retiredRe.hasMatch(item.hint), isFalse, reason: item.hint);
          expect(
            duplicateParenRe.hasMatch(item.hint),
            isFalse,
            reason: item.hint,
          );
        }
      }
      for (final skill in lesson.seedSkills) {
        expect(ipaRe.hasMatch(skill.displayLabel), isFalse, reason: skill.skillId);
        expect(chaoRe.hasMatch(skill.displayLabel), isFalse, reason: skill.skillId);
        expect(retiredRe.hasMatch(skill.displayLabel), isFalse, reason: skill.skillId);
      }
    }

    expect(
      Curriculum.lessonById('u5_l2_glide_endings')!.trialPrompt,
      'Which vowel glide do you hear?',
    );
    expect(
      Curriculum.lessonById('u5_l3_nasal_endings')!.trialPrompt,
      'Which final consonant do you hear?',
    );
    expect(
      Curriculum.lessonById('u6_l3_checked_stops')!.trialPrompt,
      'Which final consonant do you hear?',
    );
  });

  test('all 28 lesson predicates yield attested paired pools and obey phonology guards', () {
    final catalog = _buildRichFixtureCatalog();
    final byKey = {for (final e in catalog) e.key: e};

    for (final spec in Curriculum.standardLessons) {
      final pool = Curriculum.filterPool(spec, catalog);
      expect(pool, isNotEmpty, reason: '${spec.id} filtered pool empty');
      final paired = Curriculum.pairedEntries(spec, pool, byKey);
      expect(paired, isNotEmpty, reason: '${spec.id} paired pool empty');

      if (spec.unitId != 'unit_7' && spec.id != 'u6_l4_syllabic_nasals') {
        expect(
          pool.every((e) => e.nucleus.isNotEmpty),
          isTrue,
          reason: '${spec.id} leaked syllabic nasals',
        );
      }
      if (spec.id == 'u3_l4_six_tone_check') {
        expect(
          pool.every((e) => !{'p', 't', 'k'}.contains(e.coda)),
          isTrue,
          reason: 'u3_l4 must exclude checked stops',
        );
      }
      if (spec.id == 'u6_l3_checked_stops') {
        expect(
          pool.every((e) => {1, 3, 6}.contains(e.tone)),
          isTrue,
          reason: 'u6_l3 must restrict to tones 1, 3, 6',
        );
      }
      if (spec.id == 'u7_l1_start_plus_tone' ||
          spec.id == 'u7_l2_vowel_ending_tone') {
        expect(
          pool.every((e) => e.nucleus.isNotEmpty),
          isTrue,
          reason: '${spec.id} must exclude syllabic nasals',
        );
      }
    }

    for (final review in Curriculum.cumulativeReviews) {
      final session = LessonSession.startLesson(
        review,
        catalog: catalog,
        random: Random(1),
      );
      expect(session.gradedTotal, review.coreCount, reason: review.id);
    }
  });

  test('validates all 28 lessons and 5 cumulative reviews against real jyutnet syllables.json when present', () {
    final file = File('../jyutnet-audio-bundle/dist/syllables.json');
    if (!file.existsSync()) return;
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final rawList = decoded['syllables'] as List<dynamic>;
    final catalog = rawList
        .map(
          (item) => SyllableEntry.fromDbRow({
            'syllable': item['syllable'],
            'path': item['path'],
            'initial': item['initial'],
            'nucleus': item['nucleus'],
            'coda': item['coda'],
            'tone': item['tone'],
            'initial_group': item['initialGroup'],
            'priority': item['priority'],
          }),
        )
        .toList();
    final byKey = {for (final e in catalog) e.key: e};

    for (final spec in Curriculum.standardLessons) {
      final pool = Curriculum.filterPool(spec, catalog);
      final paired = Curriculum.pairedEntries(spec, pool, byKey);
      expect(pool, isNotEmpty, reason: 'Real corpus empty for ${spec.id}');
      expect(paired, isNotEmpty, reason: 'Real paired empty for ${spec.id}');
    }

    for (final review in Curriculum.cumulativeReviews) {
      final session = LessonSession.startLesson(
        review,
        catalog: catalog,
        random: Random(2),
      );
      expect(session.gradedTotal, review.coreCount, reason: review.id);
    }
  });
}
