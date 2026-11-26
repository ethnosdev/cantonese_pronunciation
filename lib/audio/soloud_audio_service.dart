import 'dart:async';
import 'dart:collection';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_playback_service.dart';

/// Plays unmodified .opus syllable clips using flutter_soloud and audio_session.
class SoLoudAudioService implements AudioPlaybackService {
  SoLoudAudioService({SoLoud? soloud}) : _soloud = soloud ?? SoLoud.instance;

  static const int _maxTurnSources = 7;

  final SoLoud _soloud;
  final LinkedHashMap<String, AudioSource> _turnSources = LinkedHashMap();

  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;
  SoundHandle? _activeHandle;
  int _requestToken = 0;
  bool _initialized = false;

  @override
  void Function(String path, Object error)? onPlaybackError;

  @override
  Future<void> init() async {
    if (_initialized) return;

    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
      ),
    );
    await session.setActive(true);

    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        unawaited(stop());
      }
    });
    _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
      unawaited(stop());
    });

    if (!_soloud.isInitialized) {
      await _soloud.init();
    }
    _initialized = true;
  }

  @override
  Future<void> playFile(String absolutePath) async {
    if (!_initialized) {
      await init();
    }
    final token = ++_requestToken;
    await _playFileWithToken(absolutePath, token);
  }

  @override
  Future<void> playSequence(
    List<String> paths, {
    Duration initialDelay = Duration.zero,
    Duration gap = const Duration(milliseconds: 450),
    void Function(int index)? onClipStart,
    void Function(int index)? onClipEnd,
  }) async {
    if (paths.isEmpty) return;
    if (!_initialized) {
      await init();
    }
    final token = ++_requestToken;
    await _stopActiveHandle();
    if (token != _requestToken) return;

    if (initialDelay > Duration.zero) {
      await Future<void>.delayed(initialDelay);
      if (token != _requestToken) return;
    }

    for (var i = 0; i < paths.length; i++) {
      if (token != _requestToken) return;
      onClipStart?.call(i);
      final handle = await _playFileWithToken(paths[i], token);
      if (handle == null || token != _requestToken) return;
      await _waitForVoiceCompletion(handle, token);
      if (token != _requestToken) return;
      onClipEnd?.call(i);
      if (i + 1 < paths.length && gap > Duration.zero) {
        await Future<void>.delayed(gap);
      }
    }
  }

  Future<SoundHandle?> _playFileWithToken(String absolutePath, int token) async {
    await _stopActiveHandle();
    if (token != _requestToken) return null;

    try {
      var source = _turnSources.remove(absolutePath);
      if (source != null) {
        // Refresh MRU position.
        _turnSources[absolutePath] = source;
      } else {
        source = await _soloud.loadFile(absolutePath);
        if (token != _requestToken) {
          await _soloud.disposeSource(source);
          return null;
        }
        while (_turnSources.length >= _maxTurnSources) {
          final oldestKey = _turnSources.keys.first;
          final oldest = _turnSources.remove(oldestKey);
          if (oldest != null) {
            await _soloud.disposeSource(oldest);
          }
        }
        _turnSources[absolutePath] = source;
      }

      if (token != _requestToken) return null;
      final handle = _soloud.play(source);
      _activeHandle = handle;
      return handle;
    } catch (error) {
      onPlaybackError?.call(absolutePath, error);
      rethrow;
    }
  }

  Future<void> _waitForVoiceCompletion(SoundHandle handle, int token) async {
    const pollInterval = Duration(milliseconds: 30);
    const maxClipDuration = Duration(milliseconds: 2500);
    var elapsed = Duration.zero;

    while (token == _requestToken &&
        elapsed < maxClipDuration &&
        _soloud.isInitialized) {
      bool valid;
      try {
        valid = _soloud.getIsValidVoiceHandle(handle);
      } catch (_) {
        valid = false;
      }
      if (!valid) break;
      await Future<void>.delayed(pollInterval);
      elapsed += pollInterval;
    }
  }

  @override
  Future<void> stop() async {
    _requestToken++;
    await _stopActiveHandle();
  }

  @override
  Future<void> clearTurnSources() async {
    _requestToken++;
    await _stopActiveHandle();
    final sources = _turnSources.values.toList();
    _turnSources.clear();
    for (final src in sources) {
      try {
        await _soloud.disposeSource(src);
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    await clearTurnSources();
    await _interruptionSub?.cancel();
    await _becomingNoisySub?.cancel();
    _interruptionSub = null;
    _becomingNoisySub = null;
    if (_soloud.isInitialized) {
      _soloud.deinit();
    }
    _initialized = false;
  }

  Future<void> _stopActiveHandle() async {
    final handle = _activeHandle;
    _activeHandle = null;
    if (handle != null && _soloud.isInitialized) {
      try {
        if (_soloud.getIsValidVoiceHandle(handle)) {
          await _soloud.stop(handle);
        }
      } catch (_) {}
    }
  }
}
