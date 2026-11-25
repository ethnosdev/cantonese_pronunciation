import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/syllable_models.dart';
import '../data/audio_bundle_repository.dart';
import '../state/bundle_controller.dart';
import '../state/quiz_controller.dart';

typedef LaunchUrlFn = Future<bool> Function(Uri url);

/// Quiz preferences, audio repair action, and CC BY-SA 4.0 / CC0 credits.
class SettingsCreditsScreen extends StatelessWidget {
  SettingsCreditsScreen({
    super.key,
    required this.bundleController,
    required this.quizController,
    LaunchUrlFn? launchUrlFn,
  }) : _launchUrl =
           launchUrlFn ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  final BundleController bundleController;
  final QuizController? quizController;
  final LaunchUrlFn _launchUrl;

  Future<void> _open(String url) async {
    await _launchUrl(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Credits')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (quizController != null)
                ListenableBuilder(
                  listenable: quizController!,
                  builder: (context, _) {
                    final s = quizController!.settings;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Quiz Settings',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<DatasetTier>(
                          initialValue: s.tier,
                          decoration: const InputDecoration(
                            labelText: 'Dataset Tier',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final t in DatasetTier.values)
                              DropdownMenuItem(value: t, child: Text(t.label)),
                          ],
                          onChanged: (t) {
                            if (t != null) {
                              quizController!.updateSettings(
                                s.copyWith(tier: t),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<ConstraintMode>(
                          segments: const [
                            ButtonSegment(
                              value: ConstraintMode.test,
                              label: Text('Test Mode'),
                            ),
                            ButtonSegment(
                              value: ConstraintMode.guided,
                              label: Text('Guided Mode'),
                            ),
                          ],
                          selected: {s.constraintMode},
                          onSelectionChanged: (sel) => quizController!
                              .updateSettings(s.copyWith(constraintMode: sel.first)),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-play next syllable'),
                          value: s.autoPlay,
                          onChanged: (v) => quizController!.updateSettings(
                            s.copyWith(autoPlay: v),
                          ),
                        ),
                        const Divider(height: 24),
                      ],
                    );
                  },
                ),
              Text(
                'Offline Audio Pack',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: bundleController,
                builder: (context, _) {
                  final repairing = bundleController.isRepairing;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: repairing
                            ? null
                            : bundleController.installOrRepair,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Verify / Re-download Audio (~19.2 MB)'),
                      ),
                      if (repairing) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: bundleController.repairProgress,
                        ),
                      ],
                      if (bundleController.repairError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          bundleController.repairError!,
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
                'Credits & Licenses',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Audio recordings (5,358 unmodified Ogg Opus clips by native Hong '
                'Kong male speaker kt) and syllable index metadata are from '
                '「粵音資料集叢」 (Cantonese Phonetics Data Collection), licensed '
                'under CC BY-SA 4.0 and provided as-is without warranty.',
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
              const SizedBox(height: 12),
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
