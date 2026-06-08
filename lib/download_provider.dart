import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'api_service.dart';

class DownloadProvider with ChangeNotifier {
  final ApiService _apiService;
  List<DownloadItem> _downloads = [];
  bool _isLoading = false;
  Timer? _timer;
  String? _error;

  DownloadProvider(this._apiService) {
    fetchDownloads();
    startPolling();
  }

  List<DownloadItem> get downloads => _downloads;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await fetchDownloads(silent: true);
    });
  }

  void stopPolling() {
    _timer?.cancel();
  }

  Future<void> fetchDownloads({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final list = await _apiService.getDownloads();
      _downloads = list;
      _error = null;
    } catch (e) {
      if (!silent) {
        _error = e.toString();
      }
      if (kDebugMode) {
        print("Error fetching downloads: $e");
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> addDownload(String name, String url) async {
    try {
      await _apiService.addDownload(name, url);
      await fetchDownloads();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pauseDownload(String id) async {
    try {
      await _apiService.pauseDownload(id);
      await fetchDownloads(silent: true);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> resumeDownload(String id) async {
    try {
      await _apiService.resumeDownload(id);
      await fetchDownloads(silent: true);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> retryDownload(String id) async {
    try {
      await _apiService.retryDownload(id);
      await fetchDownloads(silent: true);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> cancelDownload(String id) async {
    try {
      await _apiService.cancelDownload(id);
      await fetchDownloads(silent: true);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
