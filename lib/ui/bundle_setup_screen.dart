import 'package:material_ui/material_ui.dart';

import '../state/bundle_controller.dart';

/// First-run download, verification, and extraction gate screen.
class BundleSetupScreen extends StatelessWidget {
  const BundleSetupScreen({
    super.key,
    required this.bundleController,
    required this.onOpenCredits,
  });

  final BundleController bundleController;
  final VoidCallback onOpenCredits;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cantonese Pronunciation'),
        actions: [
          TextButton.icon(
            onPressed: onOpenCredits,
            icon: const Icon(Icons.info_outline),
            label: const Text('Credits'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListenableBuilder(
              listenable: bundleController,
              builder: (context, _) {
                final status = bundleController.status;
                final busy =
                    status == BundleStatus.checking ||
                    status == BundleStatus.downloading ||
                    status == BundleStatus.verifying ||
                    status == BundleStatus.extracting ||
                    status == BundleStatus.importing;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      status == BundleStatus.error ||
                              status == BundleStatus.corrupted
                          ? Icons.error_outline
                          : Icons.download_for_offline_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Download Required',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This app requires a 19 MB audio pack recorded by a native Cantonese speaker. '
                      '粵音資料集叢 has kindly made these recordings available under a CC BY-SA 4.0 license.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (busy) ...[
                      LinearProgressIndicator(value: bundleController.progress),
                      const SizedBox(height: 8),
                      Text(
                        _stageLabel(status, bundleController.progress),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (bundleController.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 160),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              bundleController.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: busy ? null : bundleController.installOrRepair,
                      icon: const Icon(Icons.download),
                      label: Text(
                        status == BundleStatus.error ||
                                status == BundleStatus.corrupted
                            ? 'Retry Download'
                            : 'Download',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _stageLabel(BundleStatus status, double? progress) {
    switch (status) {
      case BundleStatus.checking:
        return 'Checking local audio files...';
      case BundleStatus.downloading:
        final pct = progress == null ? '' : ' ${(progress * 100).round()}%';
        return 'Downloading audio archive...$pct';
      case BundleStatus.verifying:
        return 'Verifying SHA-256 checksum...';
      case BundleStatus.extracting:
        return 'Extracting 5,358 syllable recordings...';
      case BundleStatus.importing:
        return 'Indexing syllable catalog...';
      case BundleStatus.missing:
      case BundleStatus.corrupted:
      case BundleStatus.ready:
      case BundleStatus.error:
        return '';
    }
  }
}
