import 'package:flutter/foundation.dart';

import '../data/audio_bundle_repository.dart';

/// Lifecycle states for the initial audio bundle gate.
enum BundleStatus {
  checking,
  missing,
  corrupted,
  downloading,
  verifying,
  extracting,
  importing,
  ready,
  error,
}

/// Manages bundle verification, first-run download, and non-blocking repair.
class BundleController extends ChangeNotifier {
  BundleController(this._repository);

  final AudioBundleRepository _repository;

  BundleStatus _status = BundleStatus.checking;
  double? _progress;
  String? _errorMessage;
  bool _hasUsableBundle = false;
  bool _isRepairing = false;
  BundleInstallStage? _repairStage;
  double? _repairProgress;
  String? _repairError;

  BundleStatus get status => _status;
  double? get progress => _progress;
  String? get errorMessage => _errorMessage;
  bool get hasUsableBundle => _hasUsableBundle;
  bool get isRepairing => _isRepairing;
  BundleInstallStage? get repairStage => _repairStage;
  double? get repairProgress => _repairProgress;
  String? get repairError => _repairError;

  AudioBundleRepository get repository => _repository;

  /// Checks local sentinel and SQLite state with zero network requests.
  Future<void> checkInitialStatus() async {
    _status = BundleStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.cleanupOrphanedArtifacts();
      final ready = await _repository.isBundleReady();
      _hasUsableBundle = ready;
      _status = ready ? BundleStatus.ready : BundleStatus.missing;
    } catch (e) {
      _hasUsableBundle = false;
      _status = BundleStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Starts initial download/install or non-blocking Settings repair.
  Future<void> installOrRepair() async {
    if (_hasUsableBundle) {
      await _runNonBlockingRepair();
      return;
    }

    _errorMessage = null;
    _progress = 0.0;
    _status = BundleStatus.downloading;
    notifyListeners();

    try {
      await _repository.installOrRepair(
        onProgress: (stage, progress) {
          _status = _mapStage(stage);
          _progress = progress;
          notifyListeners();
        },
      );
      _hasUsableBundle = true;
      _status = BundleStatus.ready;
      _progress = 1.0;
    } catch (e) {
      _hasUsableBundle = false;
      _status = BundleStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> _runNonBlockingRepair() async {
    _isRepairing = true;
    _repairError = null;
    _repairProgress = 0.0;
    _repairStage = BundleInstallStage.downloading;
    notifyListeners();

    try {
      await _repository.installOrRepair(
        onProgress: (stage, progress) {
          _repairStage = stage;
          _repairProgress = progress;
          notifyListeners();
        },
      );
    } catch (e) {
      _repairError = e.toString();
    } finally {
      _isRepairing = false;
      notifyListeners();
    }
  }

  /// Marks the bundle corrupted when a runtime audio file fails to open.
  void markCorrupted(String reason) {
    _hasUsableBundle = false;
    _status = BundleStatus.corrupted;
    _errorMessage = reason;
    notifyListeners();
  }

  BundleStatus _mapStage(BundleInstallStage stage) {
    switch (stage) {
      case BundleInstallStage.downloading:
        return BundleStatus.downloading;
      case BundleInstallStage.verifying:
        return BundleStatus.verifying;
      case BundleInstallStage.extracting:
        return BundleStatus.extracting;
      case BundleInstallStage.importing:
        return BundleStatus.importing;
    }
  }
}
