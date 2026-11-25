/// Platform-independent interface for low-latency syllable audio playback.
abstract class AudioPlaybackService {
  void Function(String path, Object error)? onPlaybackError;

  Future<void> init();

  /// Stops any active playback and starts playing [absolutePath].
  Future<void> playFile(String absolutePath);

  /// Plays [paths] sequentially after [initialDelay] with [gap] between clips.
  ///
  /// Cancels cleanly if `playFile`, `playSequence`, `stop`, `clearTurnSources`,
  /// or `dispose` is called while waiting or between clips.
  Future<void> playSequence(
    List<String> paths, {
    Duration initialDelay = Duration.zero,
    Duration gap = const Duration(milliseconds: 450),
    void Function(int index)? onClipStart,
  });

  Future<void> stop();

  /// Releases cached turn-scoped audio sources when advancing turns.
  Future<void> clearTurnSources();

  Future<void> dispose();
}
