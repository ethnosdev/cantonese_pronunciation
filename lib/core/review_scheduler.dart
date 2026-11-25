import 'lesson_spec.dart';

/// Pure-Dart spaced-repetition scheduler for 48 contrast skills.
class ReviewScheduler {
  ReviewScheduler({DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _clock;

  /// Discrete expanding review intervals in days (stages 0..3).
  static const List<int> intervalDays = [1, 3, 7, 14];

  DateTime now() => _clock();

  /// Returns interval duration in days for [stage] clamped to 0..3.
  static int daysForStage(int stage) {
    final clamped = stage.clamp(0, intervalDays.length - 1);
    return intervalDays[clamped];
  }

  /// Creates an initial [ReviewItem] due 1 day from [seededAt].
  ReviewItem createSeededItem(ContrastSkill skill, {DateTime? seededAt}) {
    final ts = (seededAt ?? now()).toUtc();
    return ReviewItem(
      skillId: skill.skillId,
      lessonId: skill.lessonId,
      targetType: skill.targetType,
      targetValue: skill.targetValue,
      intervalStage: 0,
      dueAt: ts.add(Duration(days: intervalDays[0])),
      lapses: 0,
      lastReviewedAt: ts,
    );
  }

  /// Prioritizes overdue items: oldest `dueAt` first, then highest `lapses`.
  List<ReviewItem> selectDueQueue(
    List<ReviewItem> items, {
    DateTime? currentTime,
    int limit = DailyReviewSpec.trialTargetCount,
  }) {
    final ts = (currentTime ?? now()).toUtc();
    final due = items.where((item) => !item.dueAt.isAfter(ts)).toList();
    due.sort((a, b) {
      final dueCmp = a.dueAt.compareTo(b.dueAt);
      if (dueCmp != 0) return dueCmp;
      final lapseCmp = b.lapses.compareTo(a.lapses);
      if (lapseCmp != 0) return lapseCmp;
      return a.skillId.compareTo(b.skillId);
    });
    if (due.length <= limit) return due;
    return due.sublist(0, limit);
  }

  /// Updates a reviewed skill after Daily Review first-attempt grading.
  ReviewItem applyOutcome(
    ReviewItem item, {
    required bool passedFirstAttempt,
    DateTime? reviewedAt,
  }) {
    final ts = (reviewedAt ?? now()).toUtc();
    if (passedFirstAttempt) {
      final nextStage = (item.intervalStage + 1).clamp(
        0,
        intervalDays.length - 1,
      );
      return item.copyWith(
        intervalStage: nextStage,
        dueAt: ts.add(Duration(days: intervalDays[nextStage])),
        lastReviewedAt: ts,
      );
    }
    return item.copyWith(
      intervalStage: 0,
      dueAt: ts.add(Duration(days: intervalDays[0])),
      lapses: item.lapses + 1,
      lastReviewedAt: ts,
    );
  }
}
