import '../core/syllable_models.dart';
import 'database_helper.dart';

/// Persisted user preferences loaded from and saved to app_settings.
class AppSettings {
  const AppSettings({
    this.tier = DatasetTier.pri0,
    this.constraintMode = ConstraintMode.test,
    this.focusFilter = const AllFilter(),
    this.autoPlay = true,
  });

  final DatasetTier tier;
  final ConstraintMode constraintMode;
  final FocusFilter focusFilter;
  final bool autoPlay;

  AppSettings copyWith({
    DatasetTier? tier,
    ConstraintMode? constraintMode,
    FocusFilter? focusFilter,
    bool? autoPlay,
  }) {
    return AppSettings(
      tier: tier ?? this.tier,
      constraintMode: constraintMode ?? this.constraintMode,
      focusFilter: focusFilter ?? this.focusFilter,
      autoPlay: autoPlay ?? this.autoPlay,
    );
  }
}

/// Persists confusion_stats and app_settings in SQLite.
class StatsRepository {
  StatsRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  static const String _keyTier = 'dataset_tier';
  static const String _keyMode = 'constraint_mode';
  static const String _keyFilter = 'focus_filter';
  static const String _keyAutoPlay = 'auto_play';

  Future<void> recordAttempt(GradingResult result) async {
    if (result.statsComponents.isEmpty) return;
    final db = await _dbHelper.open();
    await db.transaction((txn) async {
      for (final comp in result.statsComponents) {
        final grade = result.grades[comp];
        if (grade == null) continue;
        await txn.rawInsert(
          '''
          INSERT INTO confusion_stats (component, expected, guessed, count)
          VALUES (?, ?, ?, 1)
          ON CONFLICT (component, expected, guessed)
          DO UPDATE SET count = count + 1
          ''',
          [comp.name, grade.expected, grade.guessed],
        );
      }
    });
  }

  Future<List<ConfusionStat>> loadAllStats() async {
    final db = await _dbHelper.open();
    final rows = await db.query('confusion_stats');
    return rows
        .map(
          (r) => ConfusionStat(
            component: ComponentType.fromName(r['component'] as String),
            expected: r['expected'] as String,
            guessed: r['guessed'] as String,
            count: r['count'] as int,
          ),
        )
        .toList();
  }

  Future<List<ComponentAccuracy>> loadComponentAccuracies() async {
    final stats = await loadAllStats();
    final totals = <ComponentType, int>{};
    final corrects = <ComponentType, int>{};
    for (final s in stats) {
      totals[s.component] = (totals[s.component] ?? 0) + s.count;
      if (s.expected == s.guessed) {
        corrects[s.component] = (corrects[s.component] ?? 0) + s.count;
      }
    }
    return ComponentType.values
        .map(
          (c) => ComponentAccuracy(
            component: c,
            correct: corrects[c] ?? 0,
            total: totals[c] ?? 0,
          ),
        )
        .toList();
  }

  Future<List<ConfusionStat>> loadTopConfusions({int limit = 10}) async {
    final db = await _dbHelper.open();
    final rows = await db.rawQuery(
      '''
      SELECT component, expected, guessed, count
      FROM confusion_stats
      WHERE expected != guessed
      ORDER BY count DESC
      LIMIT ?
      ''',
      [limit],
    );
    return rows
        .map(
          (r) => ConfusionStat(
            component: ComponentType.fromName(r['component'] as String),
            expected: r['expected'] as String,
            guessed: r['guessed'] as String,
            count: r['count'] as int,
          ),
        )
        .toList();
  }

  Future<void> resetStats() async {
    final db = await _dbHelper.open();
    await db.delete('confusion_stats');
  }

  Future<AppSettings> loadSettings() async {
    final db = await _dbHelper.open();
    final rows = await db.query('app_settings');
    final map = <String, String>{
      for (final r in rows) r['key'] as String: r['value'] as String,
    };
    return AppSettings(
      tier: DatasetTier.fromId(map[_keyTier]),
      constraintMode: ConstraintMode.fromId(map[_keyMode]),
      focusFilter: FocusFilter.fromId(map[_keyFilter]),
      autoPlay: map[_keyAutoPlay] != 'false',
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final db = await _dbHelper.open();
    await db.transaction((txn) async {
      final pairs = {
        _keyTier: settings.tier.id,
        _keyMode: settings.constraintMode.id,
        _keyFilter: settings.focusFilter.id,
        _keyAutoPlay: settings.autoPlay.toString(),
      };
      for (final entry in pairs.entries) {
        await txn.rawInsert(
          '''
          INSERT INTO app_settings (key, value)
          VALUES (?, ?)
          ON CONFLICT (key) DO UPDATE SET value = excluded.value
          ''',
          [entry.key, entry.value],
        );
      }
    });
  }
}
