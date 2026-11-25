import 'dart:math';

import 'syllable_models.dart';

/// Selects quiz targets biased toward components with higher error rates.
class WeightedSampler {
  WeightedSampler({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Picks a syllable from [pool], avoiding [previousSyllable] when possible.
  SyllableEntry pickNext({
    required List<SyllableEntry> pool,
    required List<ConfusionStat> stats,
    String? previousSyllable,
  }) {
    if (pool.isEmpty) {
      throw StateError('Cannot sample from an empty syllable pool');
    }
    if (pool.length == 1) {
      return pool.first;
    }

    final candidates = previousSyllable == null
        ? pool
        : pool.where((e) => e.syllable != previousSyllable).toList();
    final effectivePool = candidates.isEmpty ? pool : candidates;

    final errorRates = _computeSmoothedErrorRates(stats);
    final weights = <double>[];
    var totalWeight = 0.0;

    for (final entry in effectivePool) {
      final iRate = errorRates[(ComponentType.initial, entry.initial)] ?? 0.25;
      final nRate = errorRates[(ComponentType.nucleus, entry.nucleus)] ?? 0.25;
      final cRate = errorRates[(ComponentType.coda, entry.coda)] ?? 0.25;
      final tRate =
          errorRates[(ComponentType.tone, entry.tone.toString())] ?? 0.25;
      final meanError = (iRate + nRate + cRate + tRate) / 4.0;
      final weight = 1.0 + 3.0 * meanError;
      weights.add(weight);
      totalWeight += weight;
    }

    var target = _random.nextDouble() * totalWeight;
    for (var i = 0; i < effectivePool.length; i++) {
      target -= weights[i];
      if (target <= 0) {
        return effectivePool[i];
      }
    }
    return effectivePool.last;
  }

  Map<(ComponentType, String), double> _computeSmoothedErrorRates(
    List<ConfusionStat> stats,
  ) {
    final totals = <(ComponentType, String), int>{};
    final wrongs = <(ComponentType, String), int>{};

    for (final s in stats) {
      final key = (s.component, s.expected);
      totals[key] = (totals[key] ?? 0) + s.count;
      if (s.expected != s.guessed) {
        wrongs[key] = (wrongs[key] ?? 0) + s.count;
      }
    }

    final rates = <(ComponentType, String), double>{};
    for (final key in totals.keys) {
      final total = totals[key]!;
      final wrong = wrongs[key] ?? 0;
      // Laplace smoothing prevents early single-miss ping-ponging.
      rates[key] = (wrong + 0.5) / (total + 2.0);
    }
    return rates;
  }
}
