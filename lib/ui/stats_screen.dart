import 'package:material_ui/material_ui.dart';

import '../core/syllable_models.dart';
import '../data/stats_repository.dart';

/// Displays per-component accuracy, top confused pairs, and local stats reset.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.statsRepository});

  final StatsRepository statsRepository;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<ComponentAccuracy> _accuracies = const [];
  List<ConfusionStat> _confusions = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final acc = await widget.statsRepository.loadComponentAccuracies();
    final conf = await widget.statsRepository.loadTopConfusions(limit: 12);
    setState(() {
      _accuracies = acc;
      _confusions = conf;
      _loading = false;
    });
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Statistics?'),
        content: const Text(
          'This clears all locally recorded component accuracy and confusion '
          'counts on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.statsRepository.resetStats();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          IconButton(
            tooltip: 'Reset Stats',
            onPressed: _confirmReset,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Component Accuracy',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final item in _accuracies)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(item.component.label),
                                Text(
                                  item.total == 0
                                      ? 'No data'
                                      : '${(item.rate * 100).round()}% '
                                            '(${item.correct}/${item.total})',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: item.total == 0 ? 0 : item.rate,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Top Confused Pairs',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_confusions.isEmpty)
                      const Text('No confusions recorded yet.')
                    else
                      for (final c in _confusions)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${c.component.label}: '
                            '${_token(c.expected)} ↔ ${_token(c.guessed)}',
                          ),
                          trailing: Text('${c.count}×'),
                        ),
                  ],
                ),
        ),
      ),
    );
  }

  String _token(String raw) => raw.isEmpty ? '∅' : raw;
}
