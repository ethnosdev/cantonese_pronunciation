import 'package:flutter/foundation.dart';

import '../core/curriculum.dart';
import '../core/lesson_spec.dart';
import '../data/progress_repository.dart';

/// Loads unit/lesson progress and Daily Review due count for Home.
class LearningPathController extends ChangeNotifier {
  LearningPathController({
    required ProgressRepository progressRepository,
    DateTime Function()? clock,
  }) : _progressRepo = progressRepository,
       _clock = clock ?? (() => DateTime.now().toUtc());

  final ProgressRepository _progressRepo;
  final DateTime Function() _clock;

  Map<String, LessonProgressRecord> _progressByLesson = const {};
  int _dueReviewCount = 0;
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  int get dueReviewCount => _dueReviewCount;
  Map<String, LessonProgressRecord> get progressByLesson => _progressByLesson;

  int get completedLessonsCount => Curriculum.lessons
      .where((l) => statusForLesson(l.id) == LessonStatus.completed)
      .length;

  int get totalLessonsCount => Curriculum.lessons.length;

  LessonStatus statusForLesson(String lessonId) {
    final record = _progressByLesson[lessonId];
    if (record != null) return record.status;
    return lessonId == ProgressRepository.initialLessonId
        ? LessonStatus.unlocked
        : LessonStatus.locked;
  }

  LessonProgressRecord? recordForLesson(String lessonId) =>
      _progressByLesson[lessonId];

  int completedCountForUnit(String unitId) {
    return Curriculum.lessonsForUnit(unitId)
        .where((l) => statusForLesson(l.id) == LessonStatus.completed)
        .length;
  }

  /// Returns the primary next unlocked (not yet completed) lesson, or the last completed one.
  LessonSpec? get recommendedNextLesson {
    for (final lesson in Curriculum.lessons) {
      if (statusForLesson(lesson.id) == LessonStatus.unlocked) {
        return lesson;
      }
    }
    return Curriculum.lessons.isNotEmpty ? Curriculum.lessons.last : null;
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      final now = _clock();
      await _progressRepo.ensureLesson1Unlocked(now);
      _progressByLesson = await _progressRepo.loadAllLessonProgress();
      _dueReviewCount = await _progressRepo.countDueReviewItems(now);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
