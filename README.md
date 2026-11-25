# Cantonese Pronunciation

Cross-platform Flutter pronunciation app for Cantonese Jyutping supporting Android, iOS, and macOS.

## Licensing Split

- **First-party app source code:** CC0 1.0 Universal (`LICENSE`).
- **Audio & syllable index bundle:** Licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) by [「粵音資料集叢」](https://jyut.net/) (source recordings: <https://github.com/jyutnet/jyutnet-cantonese-syllables>) and downloaded separately at runtime from <https://cantonese.ethnos.dev/kt_audio_opus_v1.zip>.

## Build Configuration

Optional `--dart-define` overrides for custom audio bundle hosting during testing:

```bash
flutter run \
  --dart-define=AUDIO_BUNDLE_URL=https://cantonese.ethnos.dev/kt_audio_opus_v1.zip \
  --dart-define=AUDIO_BUNDLE_SIZE=19740191 \
  --dart-define=AUDIO_BUNDLE_SHA256=04833a88e4d78b053edacbf735baa27a73e98a9842b7d0d27f064b2b492c3087
```

## Tests

```bash
flutter analyze
flutter test
```
