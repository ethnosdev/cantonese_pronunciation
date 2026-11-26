import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../core/curriculum.dart';
import '../core/lesson_spec.dart';
import '../core/review_scheduler.dart';
import 'database_helper.dart';

/// SQLite-backed persistence for lesson progression and contrast-skill review.
class ProgressRepository {
  ProgressRepository(
    this._dbHelper, {
    DateTime Function()? clock,
  }) : _scheduler = ReviewScheduler(clock: clock);

  final DatabaseHelper _dbHelper;
  final ReviewScheduler _scheduler;

  static const String initialLessonId = 'u1_l1_high_vs_low';

  /// Seeds Lesson 1.1 as unlocked and unlocks cumulative reviews for existing progress.
  Future<void> ensureLesson1Unlocked([DateTime? now]) async {
    final ts = (now ?? _scheduler.now()).toUtc().millisecondsSinceEpoch;
    final db = await _dbHelper.open();
    await db.insert(
      'lesson_progress',
      {
        'lesson_id': initialLessonId,
        'status': LessonStatus.unlocked.name,
        'best_accuracy': 0.0,
        'attempts_count': 0,
        'last_completed_at': null,
        'updated_at': ts,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final existing = await loadAllLessonProgress();
    for (var i = 0; i < Curriculum.lessons.length; i++) {
      final spec = Curriculum.lessons[i];
      if (!spec.isCumulativeReview) continue;
      final currentStatus = existing[spec.id]?.status ?? LessonStatus.locked;
      if (currentStatus != LessonStatus.locked) continue;

      final prevCompleted =
          i > 0 &&
          existing[Curriculum.lessons[i - 1].id]?.status ==
              LessonStatus.completed;
      var anyLaterActive = false;
      for (var j = i + 1; j < Curriculum.lessons.length; j++) {
        final s = existing[Curriculum.lessons[j].id]?.status;
        if (s == LessonStatus.unlocked || s == LessonStatus.completed) {
          anyLaterActive = true;
          break;
        }
      }
      if (prevCompleted || anyLaterActive) {
        await db.insert(
          'lesson_progress',
          {
            'lesson_id': spec.id,
            'status': LessonStatus.unlocked.name,
            'best_accuracy': 0.0,
            'attempts_count': 0,
            'last_completed_at': null,
            'updated_at': ts,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  /// Loads every persisted lesson record keyed by `lesson_id`.
  Future<Map<String, LessonProgressRecord>> loadAllLessonProgress() async {
    final db = await _dbHelper.open();
    final rows = await db.query('lesson_progress');
    final map = <String, LessonProgressRecord>{};
    for (final r in rows) {
      final id = r['lesson_id'] as String;
      final completedAtMs = r['last_completed_at'] as int?;
      map[id] = LessonProgressRecord(
        lessonId: id,
        status: LessonStatus.fromDb(r['status'] as String?),
        bestAccuracy: (r['best_accuracy'] as num).toDouble(),
        attemptsCount: r['attempts_count'] as int,
        lastCompletedAt: completedAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(completedAtMs, isUtc: true)
            : null,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          r['updated_at'] as int,
          isUtc: true,
        ),
      );
    }
    return map;
  }

  /// Atomically commits a completed lesson attempt, unlocks next lesson, and seeds skills.
  Future<void> completeLessonAttempt({
    required String lessonId,
    required double accuracy,
    required bool passed,
    required String? nextLessonId,
    required List<ContrastSkill> skillsToSeed,
    DateTime? completedAt,
  }) async {
    final now = (completedAt ?? _scheduler.now()).toUtc();
    final nowMs = now.millisecondsSinceEpoch;
    final db = await _dbHelper.open();

    await db.transaction((txn) async {
      final existingRows = await txn.query(
        'lesson_progress',
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
        limit: 1,
      );
      final existing = existingRows.isEmpty ? null : existingRows.first;
      final prevStatus = LessonStatus.fromDb(existing?['status'] as String?);
      final prevBest = (existing?['best_accuracy'] as num?)?.toDouble() ?? 0.0;
      final prevAttempts = (existing?['attempts_count'] as int?) ?? 0;
      final prevCompletedAt = existing?['last_completed_at'] as int?;

      final newStatus = (passed || prevStatus == LessonStatus.completed)
          ? LessonStatus.completed.name
          : LessonStatus.unlocked.name;

      await txn.insert(
        'lesson_progress',
        {
          'lesson_id': lessonId,
          'status': newStatus,
          'best_accuracy': max(prevBest, accuracy),
          'attempts_count': prevAttempts + 1,
          'last_completed_at': passed ? nowMs : prevCompletedAt,
          'updated_at': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (passed && nextLessonId != null) {
        final nextRows = await txn.query(
          'lesson_progress',
          where: 'lesson_id = ?',
          whereArgs: [nextLessonId],
          limit: 1,
        );
        if (nextRows.isEmpty) {
          await txn.insert('lesson_progress', {
            'lesson_id': nextLessonId,
            'status': LessonStatus.unlocked.name,
            'best_accuracy': 0.0,
            'attempts_count': 0,
            'last_completed_at': null,
            'updated_at': nowMs,
          });
        } else {
          final nextStatus = LessonStatus.fromDb(
            nextRows.first['status'] as String?,
          );
          if (nextStatus == LessonStatus.locked) {
            await txn.update(
              'lesson_progress',
              {
                'status': LessonStatus.unlocked.name,
                'updated_at': nowMs,
              },
              where: 'lesson_id = ?',
              whereArgs: [nextLessonId],
            );
          }
        }
      }

      if (passed && skillsToSeed.isNotEmpty) {
        for (final skill in skillsToSeed) {
          final item = _scheduler.createSeededItem(skill, seededAt: now);
          await txn.insert(
            'review_items',
            {
              'skill_id': item.skillId,
              'lesson_id': item.lessonId,
              'target_type': item.targetType,
              'target_value': item.targetValue,
              'interval_stage': item.intervalStage,
              'due_at': item.dueAt.millisecondsSinceEpoch,
              'lapses': item.lapses,
              'last_reviewed_at': item.lastReviewedAt.millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
  }

  /// Counts review skills whose `due_at <= now`.
  Future<int> countDueReviewItems([DateTime? now]) async {
    final tsMs = (now ?? _scheduler.now()).toUtc().millisecondsSinceEpoch;
    final db = await _dbHelper.open();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM review_items WHERE due_at <= ?',
      [tsMs],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Loads overdue review skills ordered by oldest due date then highest lapses.
  Future<List<ReviewItem>> loadDueReviewItems([DateTime? now]) async {
    final tsMs = (now ?? _scheduler.now()).toUtc().millisecondsSinceEpoch;
    final db = await _dbHelper.open();
    final rows = await db.query(
      'review_items',
      where: 'due_at <= ?',
      whereArgs: [tsMs],
      orderBy: 'due_at ASC, lapses DESC, skill_id ASC',
    );
    return rows.map(_rowToReviewItem).toList(growable: false);
  }

  /// Applies updated interval/lapse state for completed Daily Review items.
  Future<void> applyReviewOutcomes(List<ReviewItem> updatedItems) async {
    if (updatedItems.isEmpty) return;
    final db = await _dbHelper.open();
    await db.transaction((txn) async {
      for (final item in updatedItems) {
        await txn.update(
          'review_items',
          {
            'interval_stage': item.intervalStage,
            'due_at': item.dueAt.millisecondsSinceEpoch,
            'lapses': item.lapses,
            'last_reviewed_at': item.lastReviewedAt.millisecondsSinceEpoch,
          },
          where: 'skill_id = ?',
          whereArgs: [item.skillId],
        );
      }
    });
  }

  /// Clears lesson mastery & spaced-review history and re-unlocks Lesson 1.1.
  Future<void> resetLearningProgress([DateTime? now]) async {
    final ts = (now ?? _scheduler.now()).toUtc().millisecondsSinceEpoch;
    final db = await _dbHelper.open();
    await db.transaction((txn) async {
      await txn.delete('lesson_progress');
      await txn.delete('review_items');
      await txn.insert('lesson_progress', {
        'lesson_id': initialLessonId,
        'status': LessonStatus.unlocked.name,
        'best_accuracy': 0.0,
        'attempts_count': 0,
        'last_completed_at': null,
        'updated_at': ts,
      });
    });
  }

  /// True when Tone Curves have been unlocked as off (`u1_l4` or `u3_l3` unlocked/completed).
  Future<bool> shouldHideToneContoursInDailyReview() async {
    final progress = await loadAllLessonProgress();
    for (final lessonId in const [
      'u1_l4_four_tone_check',
      'u3_l3_low_tones_mix',
      'u3_l4_six_tone_check',
    ]) {
      final status = progress[lessonId]?.status ?? LessonStatus.locked;
      if (status != LessonStatus.locked) return true;
    }
    return false;
  }

  /// Convenience summary of completed lessons count out of total 28.
  Future<int> countCompletedLessons() async {
    final progress = await loadAllLessonProgress();
    return Curriculum.lessons
        .where((l) => progress[l.id]?.status == LessonStatus.completed)
        .length;
  }

  ReviewItem _rowToReviewItem(Map<String, Object?> r) {
    return ReviewItem(
      skillId: r['skill_id'] as String,
      lessonId: r['lesson_id'] as String,
      targetType: r['target_type'] as String,
      targetValue: r['target_value'] as String,
      intervalStage: r['interval_stage'] as int,
      dueAt: DateTime.fromMillisecondsSinceEpoch(
        r['due_at'] as int,
        isUtc: true,
      ),
      lapses: r['lapses'] as int,
      lastReviewedAt: DateTime.fromMillisecondsSinceEpoch(
        r['last_reviewed_at'] as int,
        isUtc: true,
      ),
    );
  }
}
