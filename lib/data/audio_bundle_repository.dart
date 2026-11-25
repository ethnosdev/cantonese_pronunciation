import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/syllable_models.dart';
import 'database_helper.dart';
import 'syllable_repository.dart';

/// Progress stages emitted during audio bundle installation or repair.
enum BundleInstallStage {
  downloading,
  verifying,
  extracting,
  importing,
}

typedef ExcludeBackupFn = Future<void> Function(String path);
typedef FreeSpaceCheckFn = Future<int?> Function(Directory directory);

/// Manages download, SHA-256 verification, safe zip extraction, and SQLite import.
class AudioBundleRepository {
  AudioBundleRepository({
    required this.syllableRepository,
    required this.databaseHelper,
    http.Client? httpClient,
    Future<Directory> Function()? supportDirProvider,
    Future<Directory> Function()? tempDirProvider,
    ExcludeBackupFn? excludeFromBackup,
    FreeSpaceCheckFn? freeSpaceProvider,
    String? bundleUrl,
    int? expectedByteSize,
    String? expectedSha256,
    int? expectedFileCount,
    int? maxZipEntries,
    int? maxUncompressedBytes,
  }) : _httpClient = httpClient ?? http.Client(),
       _supportDirProvider =
           supportDirProvider ?? getApplicationSupportDirectory,
       _tempDirProvider = tempDirProvider ?? getTemporaryDirectory,
       _excludeFromBackup = excludeFromBackup ?? _defaultExcludeFromBackup,
       _freeSpaceProvider = freeSpaceProvider ?? _defaultFreeSpaceBytes,
       bundleUrl = bundleUrl ?? defaultBundleUrl,
       expectedByteSize = expectedByteSize ?? defaultBundleSize,
       expectedSha256 = expectedSha256 ?? defaultBundleSha256,
       expectedFileCount = expectedFileCount ?? defaultExpectedFileCount,
       maxZipEntries = maxZipEntries ?? defaultMaxZipEntries,
       maxUncompressedBytes =
           maxUncompressedBytes ?? defaultMaxUncompressedBytes;

  static const String defaultBundleUrl = String.fromEnvironment(
    'AUDIO_BUNDLE_URL',
    defaultValue: 'https://cantonese.ethnos.dev/kt_audio_opus_v1.zip',
  );
  static const int defaultBundleSize = int.fromEnvironment(
    'AUDIO_BUNDLE_SIZE',
    defaultValue: 19740191,
  );
  static const String defaultBundleSha256 = String.fromEnvironment(
    'AUDIO_BUNDLE_SHA256',
    defaultValue:
        '04833a88e4d78b053edacbf735baa27a73e98a9842b7d0d27f064b2b492c3087',
  );
  static const int defaultExpectedFileCount = 5358;
  static const int defaultMaxZipEntries = 5400;
  static const int defaultMaxUncompressedBytes = 60 * 1024 * 1024;
  static const int minRequiredFreeBytes = 80 * 1024 * 1024;

  static const String audioRepoUrl =
      'https://github.com/jyutnet/jyutnet-cantonese-syllables';
  static const String jyutnetUrl = 'https://jyut.net/';
  static const String ccBySaUrl =
      'https://creativecommons.org/licenses/by-sa/4.0/';

  static const String _bundleDirName = 'audio_bundle';
  static const String _stagingDirName = 'audio_staging';
  static const String _oldDirName = 'audio_bundle_old';
  static const String _sentinelFileName = '.bundle_sentinel.json';
  static const String _tempZipName = 'kt_audio_download.zip.tmp';

  final SyllableRepository syllableRepository;
  final DatabaseHelper databaseHelper;
  final http.Client _httpClient;
  final Future<Directory> Function() _supportDirProvider;
  final Future<Directory> Function() _tempDirProvider;
  final ExcludeBackupFn _excludeFromBackup;
  final FreeSpaceCheckFn _freeSpaceProvider;

  final String bundleUrl;
  final int expectedByteSize;
  final String expectedSha256;
  final int expectedFileCount;
  final int maxZipEntries;
  final int maxUncompressedBytes;

  static const MethodChannel _storageChannel = MethodChannel(
    'cantonese_pronunciation/storage',
  );

  static Future<void> _defaultExcludeFromBackup(String path) async {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    try {
      await _storageChannel.invokeMethod<bool>('excludeFromBackup', {
        'path': path,
      });
    } on MissingPluginException {
      // Ignored in pure host test environments.
    }
  }

  static Future<int?> _defaultFreeSpaceBytes(Directory dir) async {
    try {
      if (Platform.isMacOS || Platform.isLinux || Platform.isAndroid) {
        final res = await Process.run('df', ['-k', dir.path]);
        if (res.exitCode == 0) {
          final lines = res.stdout.toString().trim().split('\n');
          if (lines.length >= 2) {
            final cols = lines.last.trim().split(RegExp(r'\s+'));
            if (cols.length >= 4) {
              final kb = int.tryParse(cols[3]);
              if (kb != null) return kb * 1024;
            }
          }
        }
      }
    } catch (_) {
      // Fallback gracefully when df is unavailable on iOS sandbox.
    }
    return null;
  }

  Future<Directory> getAudioBundleDir() async {
    final supportDir = await _supportDirProvider();
    return Directory(p.join(supportDir.path, _bundleDirName));
  }

  /// Cleans up leftover staging/old directories and partial zip files.
  Future<void> cleanupOrphanedArtifacts() async {
    final supportDir = await _supportDirProvider();
    final tempDir = await _tempDirProvider();

    for (final name in [_stagingDirName, _oldDirName]) {
      final dir = Directory(p.join(supportDir.path, name));
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }

    final tempZip = File(p.join(tempDir.path, _tempZipName));
    if (tempZip.existsSync()) {
      await tempZip.delete();
    }
  }

  /// Verifies sentinel, syllables.json, and SQLite count with zero network calls.
  Future<bool> isBundleReady() async {
    final bundleDir = await getAudioBundleDir();
    final sentinelFile = File(p.join(bundleDir.path, _sentinelFileName));
    final syllablesFile = File(p.join(bundleDir.path, 'syllables.json'));
    if (!bundleDir.existsSync() ||
        !sentinelFile.existsSync() ||
        !syllablesFile.existsSync()) {
      return false;
    }

    try {
      final decoded = jsonDecode(await sentinelFile.readAsString());
      if (decoded is! Map<String, dynamic>) return false;
      if (decoded['sha256'] != expectedSha256 ||
          decoded['fileCount'] != expectedFileCount) {
        return false;
      }
      final rowCount = await syllableRepository.countSyllables();
      return rowCount == expectedFileCount;
    } catch (_) {
      return false;
    }
  }

  /// Resolves an extracted audio file path relative to the active audio bundle.
  Future<String> resolveAudioFilePath(String relativePath) async {
    final bundleDir = await getAudioBundleDir();
    final canonicalRoot = bundleDir.resolveSymbolicLinksSync();
    final joined = p.normalize(p.join(canonicalRoot, relativePath));
    if (!p.isWithin(canonicalRoot, joined)) {
      throw ArgumentError.value(relativePath, 'relativePath', 'Escapes bundle');
    }
    return joined;
  }

  /// Downloads, verifies, extracts, imports, and atomically swaps the audio pack.
  Future<void> installOrRepair({
    required void Function(BundleInstallStage stage, double? progress)
    onProgress,
  }) async {
    await cleanupOrphanedArtifacts();
    final supportDir = await _supportDirProvider();
    final tempDir = await _tempDirProvider();
    if (!supportDir.existsSync()) {
      await supportDir.create(recursive: true);
    }
    if (!tempDir.existsSync()) {
      await tempDir.create(recursive: true);
    }

    final freeBytes = await _freeSpaceProvider(supportDir);
    if (freeBytes != null && freeBytes < minRequiredFreeBytes) {
      throw FileSystemException(
        'Insufficient free storage space (need at least 80 MB)',
        supportDir.path,
      );
    }

    final tempZip = File(p.join(tempDir.path, _tempZipName));
    final stagingDir = Directory(p.join(supportDir.path, _stagingDirName));
    final bundleDir = Directory(p.join(supportDir.path, _bundleDirName));
    final oldDir = Directory(p.join(supportDir.path, _oldDirName));

    try {
      onProgress(BundleInstallStage.downloading, 0.0);
      final downloaded = await _downloadWithDigest(tempZip, (received, total) {
        final denom = total > 0 ? total : expectedByteSize;
        onProgress(
          BundleInstallStage.downloading,
          denom > 0 ? (received / denom).clamp(0.0, 1.0) : null,
        );
      });

      onProgress(BundleInstallStage.verifying, null);
      if (downloaded.byteCount != expectedByteSize) {
        throw FormatException(
          'Unexpected download size: got ${downloaded.byteCount}, '
          'expected $expectedByteSize',
        );
      }
      if (downloaded.sha256Hex != expectedSha256) {
        throw FormatException(
          'SHA-256 mismatch: got ${downloaded.sha256Hex}',
        );
      }

      onProgress(BundleInstallStage.extracting, null);
      await stagingDir.create(recursive: true);
      await _runExtractInIsolate(
        zipPath: tempZip.path,
        destPath: stagingDir.path,
        maxEntries: maxZipEntries,
        maxUncompressedBytes: maxUncompressedBytes,
      );

      onProgress(BundleInstallStage.importing, null);
      final entries = await _parseAndValidateCatalog(stagingDir);
      await syllableRepository.replaceAllFromEntries(entries);

      // Two-step atomic directory swap preserving prior bundle on failure.
      if (bundleDir.existsSync()) {
        await bundleDir.rename(oldDir.path);
      }
      await stagingDir.rename(bundleDir.path);

      final sentinelFile = File(p.join(bundleDir.path, _sentinelFileName));
      await sentinelFile.writeAsString(
        jsonEncode({
          'version': 1,
          'sha256': expectedSha256,
          'fileCount': expectedFileCount,
        }),
        flush: true,
      );

      await _excludeFromBackup(bundleDir.path);
      final dbPath = await databaseHelper.resolveDbPath();
      await _excludeFromBackup(dbPath);

      if (oldDir.existsSync()) {
        await oldDir.delete(recursive: true);
      }
    } catch (e) {
      // Restore old bundle if swap failed mid-way.
      if (!bundleDir.existsSync() && oldDir.existsSync()) {
        try {
          await oldDir.rename(bundleDir.path);
        } catch (_) {}
      }
      rethrow;
    } finally {
      if (tempZip.existsSync()) {
        try {
          await tempZip.delete();
        } catch (_) {}
      }
      if (stagingDir.existsSync()) {
        try {
          await stagingDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<({int byteCount, String sha256Hex})> _downloadWithDigest(
    File destFile,
    void Function(int received, int total) onBytes,
  ) async {
    final uri = Uri.parse(bundleUrl);
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw ArgumentError('Unsupported bundle URL scheme: ${uri.scheme}');
    }

    final request = http.Request('GET', uri);
    final response = await _httpClient.send(request);
    if (response.statusCode != 200) {
      throw HttpException(
        'Audio bundle download failed (HTTP ${response.statusCode})',
        uri: uri,
      );
    }

    final total = response.contentLength ?? expectedByteSize;
    final sink = destFile.openWrite();
    final digestOutput = _DigestAccumulator();
    final shaSink = sha256.startChunkedConversion(digestOutput);
    var received = 0;

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        shaSink.add(chunk);
        received += chunk.length;
        onBytes(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
      shaSink.close();
    }

    return (byteCount: received, sha256Hex: digestOutput.value.toString());
  }

  Future<List<SyllableEntry>> _parseAndValidateCatalog(
    Directory stagingDir,
  ) async {
    final catalogFile = File(p.join(stagingDir.path, 'syllables.json'));
    if (!catalogFile.existsSync()) {
      throw const FormatException('Missing syllables.json inside audio bundle');
    }

    final decoded = jsonDecode(await catalogFile.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('syllables.json root must be a JSON object');
    }
    final rawList = decoded['syllables'];
    if (rawList is! List) {
      throw const FormatException('syllables.json missing "syllables" list');
    }
    if (rawList.length != expectedFileCount) {
      throw FormatException(
        'Expected $expectedFileCount syllables, found ${rawList.length}',
      );
    }

    final canonicalRoot = stagingDir.resolveSymbolicLinksSync();
    final entries = <SyllableEntry>[];
    for (final item in rawList) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid syllable entry object');
      }
      final syllable = item['syllable'];
      final relPath = item['path'];
      final initial = item['initial'];
      final nucleus = item['nucleus'];
      final coda = item['coda'];
      final tone = item['tone'];
      final initialGroup = item['initialGroup'];
      final priority = item['priority'];

      if (syllable is! String ||
          syllable.isEmpty ||
          relPath is! String ||
          relPath.isEmpty ||
          initial is! String ||
          nucleus is! String ||
          coda is! String ||
          tone is! int ||
          tone < 1 ||
          tone > 6 ||
          initialGroup is! int ||
          initialGroup < 0 ||
          initialGroup > 5 ||
          priority is! int ||
          (priority != -1 &&
              priority != 0 &&
              priority != 1 &&
              priority != 2)) {
        throw FormatException('Invalid syllable field values for $syllable');
      }

      if (p.isAbsolute(relPath) || relPath.split('/').contains('..')) {
        throw FormatException('Unsafe relative path "$relPath"');
      }
      final joined = p.normalize(p.join(canonicalRoot, relPath));
      if (!p.isWithin(canonicalRoot, joined)) {
        throw FormatException('Syllable path escapes bundle: "$relPath"');
      }

      entries.add(
        SyllableEntry(
          syllable: syllable,
          path: relPath,
          initial: initial,
          nucleus: nucleus,
          coda: coda,
          tone: tone,
          initialGroup: initialGroup,
          priority: priority,
        ),
      );
    }

    return entries;
  }
}

class _DigestAccumulator implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

Future<void> _runExtractInIsolate({
  required String zipPath,
  required String destPath,
  required int maxEntries,
  required int maxUncompressedBytes,
}) {
  return Isolate.run(
    () => _extractZipSafely(
      zipPath: zipPath,
      destPath: destPath,
      maxEntries: maxEntries,
      maxUncompressedBytes: maxUncompressedBytes,
    ),
  );
}

void _extractZipSafely({
  required String zipPath,
  required String destPath,
  required int maxEntries,
  required int maxUncompressedBytes,
}) {
  final destDir = Directory(destPath);
  final canonicalDest = destDir.resolveSymbolicLinksSync();
  final inputStream = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(inputStream);
    if (archive.length > maxEntries) {
      throw FormatException(
        'Zip entry count ${archive.length} exceeds cap $maxEntries',
      );
    }

    var totalUncompressed = 0;
    for (final file in archive) {
      if (file.isSymbolicLink) {
        throw FormatException('Zip contains forbidden symlink: ${file.name}');
      }
      final entryName = file.name.replaceAll('\\', '/');
      if (entryName.isEmpty ||
          entryName.startsWith('/') ||
          entryName.split('/').contains('..')) {
        throw FormatException('Unsafe zip entry path: ${file.name}');
      }

      final targetPath = p.normalize(p.join(canonicalDest, entryName));
      if (!p.isWithin(canonicalDest, targetPath) &&
          targetPath != canonicalDest) {
        throw FormatException('Zip-Slip path escape: ${file.name}');
      }

      if (file.isFile) {
        totalUncompressed += file.size;
        if (totalUncompressed > maxUncompressedBytes) {
          throw FormatException(
            'Uncompressed zip exceeds $maxUncompressedBytes bytes',
          );
        }
        final outFile = File(targetPath);
        outFile.parent.createSync(recursive: true);
        final out = OutputFileStream(outFile.path);
        try {
          file.writeContent(out);
        } finally {
          out.close();
        }
      } else {
        Directory(targetPath).createSync(recursive: true);
      }
    }
  } finally {
    inputStream.close();
  }
}
