import 'package:material_ui/material_ui.dart';

import '../audio/audio_playback_service.dart';
import '../core/syllable_models.dart';
import '../data/audio_bundle_repository.dart';
import '../data/syllable_repository.dart';

/// Free-play reference browser grouped by final with 6-tone play rows.
class SoundboardScreen extends StatefulWidget {
  const SoundboardScreen({
    super.key,
    required this.syllableRepository,
    required this.bundleRepository,
    required this.audioService,
    required this.initialTier,
  });

  final SyllableRepository syllableRepository;
  final AudioBundleRepository bundleRepository;
  final AudioPlaybackService audioService;
  final DatasetTier initialTier;

  @override
  State<SoundboardScreen> createState() => _SoundboardScreenState();
}

class _SoundboardScreenState extends State<SoundboardScreen> {
  late DatasetTier _tier = widget.initialTier;
  List<SyllableEntry> _entries = const [];
  List<String> _finals = const [];
  String? _selectedFinal;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pool = await widget.syllableRepository.loadPool(_tier);
    final finalsSet = <String>{};
    for (final e in pool) {
      finalsSet.add('${e.nucleus}${e.coda}');
    }
    final finals = finalsSet.toList()..sort();
    setState(() {
      _entries = pool;
      _finals = finals;
      if (_selectedFinal == null || !finalsSet.contains(_selectedFinal)) {
        _selectedFinal = finals.isNotEmpty ? finals.first : null;
      }
      _loading = false;
    });
  }

  Future<void> _play(SyllableEntry entry) async {
    final fullPath = await widget.bundleRepository.resolveAudioFilePath(
      entry.path,
    );
    await widget.audioService.playFile(fullPath);
  }

  @override
  Widget build(BuildContext context) {
    final matching = _selectedFinal == null
        ? const <SyllableEntry>[]
        : _entries
              .where((e) => '${e.nucleus}${e.coda}' == _selectedFinal)
              .toList();

    final byInitial = <String, Map<int, SyllableEntry>>{};
    for (final e in matching) {
      byInitial.putIfAbsent(e.initial, () => {})[e.tone] = e;
    }
    final initials = byInitial.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Soundboard')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Text(
                        'Tap any syllable to compare tones and initials. '
                        'Hearing subtle contrasts trains accurate pronunciation.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<DatasetTier>(
                              initialValue: _tier,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Pool',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final t in DatasetTier.values)
                                  DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      t.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (t) {
                                if (t != null) {
                                  _tier = t;
                                  _load();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedFinal,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Final',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final f in _finals)
                                  DropdownMenuItem(value: f, child: Text(f)),
                              ],
                              onChanged: (f) =>
                                  setState(() => _selectedFinal = f),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: initials.length,
                        itemBuilder: (context, index) {
                          final ini = initials[index];
                          final toneMap = byInitial[ini]!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    ini.isEmpty ? '∅' : ini,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                for (var t = 1; t <= 6; t++) ...[
                                  if (t > 1) const SizedBox(width: 4),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: toneMap[t] != null
                                          ? () => _play(toneMap[t]!)
                                          : null,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        minimumSize: Size.zero,
                                      ),
                                      child: Text(
                                        '$t',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
