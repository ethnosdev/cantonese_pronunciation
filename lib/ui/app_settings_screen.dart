import 'package:material_ui/material_ui.dart';

import '../data/progress_repository.dart';
import '../data/stats_repository.dart';
import '../state/bundle_controller.dart';

/// Application settings screen accessed from the Home navigation drawer.
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({
    super.key,
    required this.statsRepository,
    required this.themeNotifier,
    required this.bundleController,
    required this.progressRepository,
    this.onProgressReset,
  });

  final StatsRepository statsRepository;
  final ValueNotifier<ThemeMode> themeNotifier;
  final BundleController bundleController;
  final ProgressRepository progressRepository;
  final VoidCallback? onProgressReset;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _autoPlay = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final autoPlay = await widget.statsRepository.loadAutoPlay();
    if (!mounted) return;
    setState(() {
      _autoPlay = autoPlay;
      _loading = false;
    });
  }

  Future<void> _setTheme(ThemeMode mode) async {
    widget.themeNotifier.value = mode;
    await widget.statsRepository.saveThemeMode(mode);
  }

  Future<void> _setAutoPlay(bool value) async {
    setState(() => _autoPlay = value);
    await widget.statsRepository.saveAutoPlay(value);
  }

  Future<void> _confirmResetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Learning Progress?'),
        content: const Text(
          'This locks Lessons 1.2–7.4 again and clears scheduled Daily Review '
          'items on this device. Audio clips remain installed.',
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
      await widget.progressRepository.resetLearningProgress();
      widget.onProgressReset?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Learning progress reset.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Appearance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: widget.themeNotifier,
                      builder: (context, currentMode, _) {
                        return SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System'),
                              icon: Icon(Icons.brightness_auto_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light'),
                              icon: Icon(Icons.light_mode_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                              icon: Icon(Icons.dark_mode_outlined),
                            ),
                          ],
                          selected: {currentMode},
                          onSelectionChanged: (sel) => _setTheme(sel.first),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Audio',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-play syllable audio'),
                      subtitle: const Text(
                        'Play each listening prompt automatically when a trial starts',
                      ),
                      value: _autoPlay,
                      onChanged: _setAutoPlay,
                    ),
                    const Divider(height: 28),
                    Text(
                      'Offline Audio Pack',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ListenableBuilder(
                      listenable: widget.bundleController,
                      builder: (context, _) {
                        final repairing = widget.bundleController.isRepairing;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton.icon(
                              onPressed: repairing
                                  ? null
                                  : widget.bundleController.installOrRepair,
                              icon: const Icon(Icons.verified_outlined),
                              label: const Text(
                                'Verify / Re-download Audio (~19.2 MB)',
                              ),
                            ),
                            if (repairing) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: widget.bundleController.repairProgress,
                              ),
                            ],
                            if (widget.bundleController.repairError != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                widget.bundleController.repairError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const Divider(height: 28),
                    Text(
                      'Progress Data',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _confirmResetProgress,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset Learning Progress'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
