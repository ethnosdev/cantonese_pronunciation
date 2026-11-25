import 'package:sqflite/sqflite.dart';

import '../core/syllable_models.dart';
import 'database_helper.dart';

/// SQLite-backed access to the 5,358 Cantonese syllable records.
class SyllableRepository {
  SyllableRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  /// Replaces only the syllables table inside one transaction.
  Future<void> replaceAllFromEntries(List<SyllableEntry> entries) async {
    final db = await _dbHelper.open();
    await db.transaction((txn) async {
      await txn.delete('syllables');
      const chunkSize = 500;
      for (var i = 0; i < entries.length; i += chunkSize) {
        final end = (i + chunkSize < entries.length)
            ? i + chunkSize
            : entries.length;
        final batch = txn.batch();
        for (var j = i; j < end; j++) {
          batch.insert(
            'syllables',
            entries[j].toDbRow(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<int> countSyllables() async {
    final db = await _dbHelper.open();
    final rows = await db.rawQuery('SELECT COUNT(*) AS cnt FROM syllables');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<List<SyllableEntry>> loadAll() async {
    final db = await _dbHelper.open();
    final rows = await db.query('syllables', orderBy: 'syllable ASC');
    return rows.map(SyllableEntry.fromDbRow).toList();
  }

  Future<List<SyllableEntry>> loadPool(
    DatasetTier tier, [
    FocusFilter filter = const AllFilter(),
  ]) async {
    final db = await _dbHelper.open();
    String? where;
    switch (tier) {
      case DatasetTier.pri0:
        where = 'priority = 0';
      case DatasetTier.pri0And1:
        where = 'priority IN (0, 1)';
      case DatasetTier.allRecorded:
        where = null;
    }
    final rows = await db.query('syllables', where: where);
    final entries = rows.map(SyllableEntry.fromDbRow);
    if (filter is AllFilter || filter is TonesOnlyFilter) {
      return entries.toList();
    }
    return entries.where(filter.matches).toList();
  }

  Future<SyllableEntry?> findByKey(SyllableKey key) async {
    final db = await _dbHelper.open();
    final rows = await db.query(
      'syllables',
      where: 'initial = ? AND nucleus = ? AND coda = ? AND tone = ?',
      whereArgs: [key.initial, key.nucleus, key.coda, key.tone],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SyllableEntry.fromDbRow(rows.first);
  }

  Future<List<SyllableEntry>> loadToneFamily(
    String initial,
    String nucleus,
    String coda,
  ) async {
    final db = await _dbHelper.open();
    final rows = await db.query(
      'syllables',
      where: 'initial = ? AND nucleus = ? AND coda = ?',
      whereArgs: [initial, nucleus, coda],
      orderBy: 'tone ASC',
    );
    return rows.map(SyllableEntry.fromDbRow).toList();
  }
}
