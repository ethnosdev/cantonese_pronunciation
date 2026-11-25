import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/audio_bundle_repository.dart';
import '../state/bundle_controller.dart';

typedef LaunchUrlFn = Future<bool> Function(Uri url);

/// About, CC BY-SA 4.0 / CC0 licensing credits, and installed bundle summary.
class AboutCreditsScreen extends StatelessWidget {
  AboutCreditsScreen({
    super.key,
    required this.bundleController,
    LaunchUrlFn? launchUrlFn,
  }) : _launchUrl =
           launchUrlFn ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  final BundleController bundleController;
  final LaunchUrlFn _launchUrl;

  Future<void> _open(String url) async {
    await _launchUrl(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About & Credits')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Audio Corpus & Attribution',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Audio recordings (5,358 unmodified Ogg Opus clips by native '
                'Hong Kong male speaker kt) and syllable index metadata are '
                'from 「粵音資料集叢」 (Cantonese Phonetics Data Collection), '
                'licensed under CC BY-SA 4.0 and provided as-is without warranty.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    label: const Text('jyut.net'),
                    onPressed: () => _open(AudioBundleRepository.jyutnetUrl),
                  ),
                  ActionChip(
                    label: const Text('CC BY-SA 4.0'),
                    onPressed: () => _open(AudioBundleRepository.ccBySaUrl),
                  ),
                  ActionChip(
                    label: const Text('Audio Source Repo'),
                    onPressed: () => _open(AudioBundleRepository.audioRepoUrl),
                  ),
                ],
              ),
              const Divider(height: 28),
              Text(
                'Offline Bundle Status',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: bundleController,
                builder: (context, _) {
                  final ready = bundleController.hasUsableBundle;
                  return Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            ready
                                ? Icons.check_circle_outline
                                : Icons.cloud_download_outlined,
                            color: ready
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ready
                                  ? 'Installed: ${bundleController.repository.expectedFileCount} '
                                        '.opus clips (~19.2 MB)'
                                  : 'Not installed (${bundleController.status.name})',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 28),
              Text(
                'Application License',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'First-party application source code is dedicated under CC0 1.0 '
                'Universal. Third-party Flutter/Dart libraries (including '
                'flutter_soloud/SoLoud, Xiph libopus/libogg, and sqflite) '
                'carry their respective open-source licenses.',
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Cantonese Pronunciation',
                ),
                child: const Text('View Open-Source Licenses'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
