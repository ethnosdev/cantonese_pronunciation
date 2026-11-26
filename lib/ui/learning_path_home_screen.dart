import 'package:material_ui/material_ui.dart';

import '../core/curriculum.dart';
import '../core/lesson_spec.dart';
import '../state/learning_path_controller.dart';

/// Primary beginner Home screen displaying the 7-unit Learning Path and Drawer.
class LearningPathHomeScreen extends StatelessWidget {
  const LearningPathHomeScreen({
    super.key,
    required this.controller,
    required this.onStartLesson,
    required this.onOpenSandbox,
    required this.onOpenSoundboard,
    required this.onOpenStats,
    required this.onOpenSettings,
    required this.onOpenAbout,
  });

  final LearningPathController controller;
  final Future<void> Function(LessonSpec lesson) onStartLesson;
  final VoidCallback onOpenSandbox;
  final VoidCallback onOpenSoundboard;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAbout;

  void _navigateFromDrawer(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Cantonese Pronunciation', maxLines: 1),
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.45),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Cantonese Pronunciation',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${controller.completedLessonsCount} / '
                          '${controller.totalLessonsCount} completed',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Free Explore',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.keyboard_alt_outlined),
                    title: const Text('Practice'),
                    onTap: () => _navigateFromDrawer(context, onOpenSandbox),
                  ),
                  ListTile(
                    leading: const Icon(Icons.grid_view_rounded),
                    title: const Text('Soundboard'),
                    onTap: () => _navigateFromDrawer(context, onOpenSoundboard),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bar_chart_rounded),
                    title: const Text('Statistics'),
                    onTap: () => _navigateFromDrawer(context, onOpenStats),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    onTap: () => _navigateFromDrawer(context, onOpenSettings),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About & Credits'),
                    onTap: () => _navigateFromDrawer(context, onOpenAbout),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                if (controller.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final nextLesson = controller.recommendedNextLesson;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    if (nextLesson != null) ...[
                      _ContinueLessonBanner(
                        lesson: nextLesson,
                        isCompleted:
                            controller.statusForLesson(nextLesson.id) ==
                            LessonStatus.completed,
                        completedCount: controller.completedLessonsCount,
                        totalCount: controller.totalLessonsCount,
                        onTap: () => onStartLesson(nextLesson),
                      ),
                      const SizedBox(height: 16),
                    ],
                    for (final unit in Curriculum.units) ...[
                      _UnitSectionCard(
                        unit: unit,
                        controller: controller,
                        onStartLesson: onStartLesson,
                      ),
                      const SizedBox(height: 14),
                      if (Curriculum.cumulativeReviewAfterUnit(unit.id)
                          case final review?) ...[
                        _CumulativeReviewCard(
                          review: review,
                          status: controller.statusForLesson(review.id),
                          record: controller.recordForLesson(review.id),
                          onTap: () => onStartLesson(review),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueLessonBanner extends StatelessWidget {
  const _ContinueLessonBanner({
    required this.lesson,
    required this.isCompleted,
    required this.completedCount,
    required this.totalCount,
    required this.onTap,
  });

  final LessonSpec lesson;
  final bool isCompleted;
  final int completedCount;
  final int totalCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCompleted ? 'Course Completed' : 'Up Next',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$completedCount / $totalCount',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              lesson.isCumulativeReview
                  ? lesson.title
                  : 'Lesson ${lesson.numberLabel}: ${lesson.title}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: totalCount == 0 ? 0 : completedCount / totalCount,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                lesson.isCumulativeReview
                    ? (isCompleted
                          ? 'Replay Cumulative Review'
                          : 'Start Cumulative Review')
                    : (isCompleted
                          ? 'Practice Lesson ${lesson.numberLabel}'
                          : 'Continue Lesson ${lesson.numberLabel}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitSectionCard extends StatelessWidget {
  const _UnitSectionCard({
    required this.unit,
    required this.controller,
    required this.onStartLesson,
  });

  final UnitSpec unit;
  final LearningPathController controller;
  final Future<void> Function(LessonSpec lesson) onStartLesson;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unitLessons = Curriculum.lessonsForUnit(unit.id);
    final completed = controller.completedCountForUnit(unit.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    '${unit.number}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        unit.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$completed/${unitLessons.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < unitLessons.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _LessonTile(
                lesson: unitLessons[i],
                status: controller.statusForLesson(unitLessons[i].id),
                record: controller.recordForLesson(unitLessons[i].id),
                onTap: () => onStartLesson(unitLessons[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.status,
    required this.record,
    required this.onTap,
  });

  final LessonSpec lesson;
  final LessonStatus status;
  final LessonProgressRecord? record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = status == LessonStatus.locked;
    final completed = status == LessonStatus.completed;

    final Color bg = completed
        ? scheme.primaryContainer.withValues(alpha: 0.35)
        : (locked ? scheme.surfaceContainerLow : scheme.surface);
    final Color border = completed
        ? scheme.primary
        : (locked ? scheme.outlineVariant.withValues(alpha: 0.5) : scheme.outline);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: locked ? 1.0 : 1.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                completed
                    ? Icons.check_circle
                    : (locked
                          ? Icons.lock_outline
                          : Icons.play_circle_outline),
                color: completed
                    ? scheme.primary
                    : (locked ? scheme.outline : scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${lesson.numberLabel}  ${lesson.title}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: locked ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                    if (record != null && record!.attemptsCount > 0)
                      Text(
                        'Best: ${(record!.bestAccuracy * 100).round()}%  •  '
                        '${lesson.coreCount} trials',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Text(
                        '${lesson.coreCount} trials',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (!locked)
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _CumulativeReviewCard extends StatelessWidget {
  const _CumulativeReviewCard({
    required this.review,
    required this.status,
    required this.record,
    required this.onTap,
  });

  final LessonSpec review;
  final LessonStatus status;
  final LessonProgressRecord? record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = status == LessonStatus.locked;
    final completed = status == LessonStatus.completed;

    final Color bg = completed
        ? scheme.primaryContainer.withValues(alpha: 0.4)
        : (locked
              ? scheme.surfaceContainerLow
              : scheme.secondaryContainer.withValues(alpha: 0.55));
    final Color border = completed
        ? scheme.primary
        : (locked
              ? scheme.outlineVariant.withValues(alpha: 0.5)
              : scheme.secondary);

    final meta = record != null && record!.attemptsCount > 0
        ? 'Best: ${(record!.bestAccuracy * 100).round()}%  •  '
              '${review.coreCount} questions'
        : '${review.coreCount} questions';

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: locked ? 1.0 : 1.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                completed
                    ? Icons.check_circle
                    : (locked ? Icons.lock_outline : Icons.verified_outlined),
                color: locked
                    ? scheme.outline
                    : (completed ? scheme.primary : scheme.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: locked ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.cue,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!locked) ...[
                const SizedBox(width: 8),
                if (completed)
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
                else
                  FilledButton.tonal(
                    onPressed: onTap,
                    child: const Text('Review'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
