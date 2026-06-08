import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const String keyBackendUrl = 'backend_url';
  static const String keyHttpServerUrl = 'http_server_url';
  static const String keyProxyHost = 'proxy_host';
  static const String keyProxyPort = 'proxy_port';
  static const String keyProxyUser = 'proxy_user';
  static const String keyProxyPass = 'proxy_pass';
  static const String keyProxyEnabled = 'proxy_enabled';

  static const String keyMaxConcurrentDownloads = 'max_concurrent_downloads';
  static const String keyDownloadDir = 'download_dir';
  static const String keyPreferredDownloadMethod = 'preferred_download_method';

  // Default values requested by the user
  static const String defaultHttpServer = 'http://172.16.50.4/';
  static const String defaultProxyHost = '103.166.253.92';
  static const int defaultProxyPort = 1088;
  static const String defaultProxyUser = 'test';
  static const String defaultProxyPass = 'test';

  String _backendUrl = 'http://localhost:3000';
  String _httpServerUrl = defaultHttpServer;
  String _proxyHost = defaultProxyHost;
  int _proxyPort = defaultProxyPort;
  String _proxyUser = defaultProxyUser;
  String _proxyPass = defaultProxyPass;
  bool _proxyEnabled = true;

  int _maxConcurrentDownloads = 3;
  String _downloadDir = 'downloads';
  String _preferredDownloadMethod = 'prompt'; // 'prompt', 'direct', 'server'

  bool _isLoaded = false;

  SettingsProvider() {
    _loadSettings();
  }

  bool get isLoaded => _isLoaded;
  String get backendUrl => _backendUrl;
  String get httpServerUrl => _httpServerUrl;
  String get proxyHost => _proxyHost;
  int get proxyPort => _proxyPort;
  String get proxyUser => _proxyUser;
  String get proxyPass => _proxyPass;
  bool get proxyEnabled => _proxyEnabled;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  String get downloadDir => _downloadDir;
  String get preferredDownloadMethod => _preferredDownloadMethod;

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _backendUrl = prefs.getString(keyBackendUrl) ?? 'http://localhost:3000';
      _httpServerUrl = prefs.getString(keyHttpServerUrl) ?? defaultHttpServer;
      _proxyHost = prefs.getString(keyProxyHost) ?? defaultProxyHost;
      _proxyPort = prefs.getInt(keyProxyPort) ?? defaultProxyPort;
      _proxyUser = prefs.getString(keyProxyUser) ?? defaultProxyUser;
      _proxyPass = prefs.getString(keyProxyPass) ?? defaultProxyPass;
      _proxyEnabled = prefs.getBool(keyProxyEnabled) ?? true;
      _maxConcurrentDownloads = prefs.getInt(keyMaxConcurrentDownloads) ?? 3;
      _downloadDir = prefs.getString(keyDownloadDir) ?? 'downloads';
      _preferredDownloadMethod = prefs.getString(keyPreferredDownloadMethod) ?? 'prompt';
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Error loading settings: $e");
      }
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> updateSettings({
    String? backendUrl,
    String? httpServerUrl,
    String? proxyHost,
    int? proxyPort,
    String? proxyUser,
    String? proxyPass,
    bool? proxyEnabled,
    int? maxConcurrentDownloads,
    String? downloadDir,
    String? preferredDownloadMethod,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (backendUrl != null) {
      _backendUrl = backendUrl;
      await prefs.setString(keyBackendUrl, backendUrl);
    }
    if (httpServerUrl != null) {
      _httpServerUrl = httpServerUrl;
      await prefs.setString(keyHttpServerUrl, httpServerUrl);
    }
    if (proxyHost != null) {
      _proxyHost = proxyHost;
      await prefs.setString(keyProxyHost, proxyHost);
    }
    if (proxyPort != null) {
      _proxyPort = proxyPort;
      await prefs.setInt(keyProxyPort, proxyPort);
    }
    if (proxyUser != null) {
      _proxyUser = proxyUser;
      await prefs.setString(keyProxyUser, proxyUser);
    }
    if (proxyPass != null) {
      _proxyPass = proxyPass;
      await prefs.setString(keyProxyPass, proxyPass);
    }
    if (proxyEnabled != null) {
      _proxyEnabled = proxyEnabled;
      await prefs.setBool(keyProxyEnabled, proxyEnabled);
    }
    if (maxConcurrentDownloads != null) {
      _maxConcurrentDownloads = maxConcurrentDownloads;
      await prefs.setInt(keyMaxConcurrentDownloads, maxConcurrentDownloads);
    }
    if (downloadDir != null) {
      _downloadDir = downloadDir;
      await prefs.setString(keyDownloadDir, downloadDir);
    }
    if (preferredDownloadMethod != null) {
      _preferredDownloadMethod = preferredDownloadMethod;
      await prefs.setString(keyPreferredDownloadMethod, preferredDownloadMethod);
    }

    notifyListeners();
  }
}
