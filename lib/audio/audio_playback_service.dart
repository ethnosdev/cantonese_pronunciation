/// Platform-independent interface for low-latency syllable audio playback.
abstract class AudioPlaybackService {
  void Function(String path, Object error)? onPlaybackError;

  Future<void> init();

  /// Stops any active playback and starts playing [absolutePath].
  Future<void> playFile(String absolutePath);

  Future<void> stop();

  /// Releases cached turn-scoped audio sources when advancing turns.
  Future<void> clearTurnSources();

  Future<void> dispose();
}
