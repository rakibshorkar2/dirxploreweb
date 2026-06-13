import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models.dart';

class SettingsProvider with ChangeNotifier {
  static const String keyBackendUrl = 'backend_url';
  static const String keyHttpServerUrl = 'http_server_url';
  static const String keyProxyHost = 'proxy_host';
  static const String keyProxyPort = 'proxy_port';
  static const String keyProxyUser = 'proxy_user';
  static const String keyProxyPass = 'proxy_pass';
  static const String keyProxyEnabled = 'proxy_enabled';
  static const String keyHttpServerUrls = 'http_server_urls';
  static const String keyProxies = 'proxies';

  static const String keyMaxConcurrentDownloads = 'max_concurrent_downloads';
  static const String keyDownloadDir = 'download_dir';
  static const String keyPreferredDownloadMethod = 'preferred_download_method';

  // Default values requested by the user
  static const String defaultHttpServer = 'http://172.16.50.4/';
  static const String defaultProxyHost = '103.166.253.92';
  static const int defaultProxyPort = 1088;
  static const String defaultProxyUser = 'test';
  static const String defaultProxyPass = 'test';

  String _backendUrl = const String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:3000');
  String _httpServerUrl = defaultHttpServer;
  List<String> _httpServerUrls = [defaultHttpServer];
  String _proxyHost = defaultProxyHost;
  int _proxyPort = defaultProxyPort;
  String _proxyUser = defaultProxyUser;
  String _proxyPass = defaultProxyPass;
  bool _proxyEnabled = true;
  List<ProxyConfig> _proxies = [
    ProxyConfig(
      host: defaultProxyHost,
      port: defaultProxyPort,
      username: defaultProxyUser,
      password: defaultProxyPass,
    )
  ];
  List<BookmarkItem> _bookmarks = [];

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
  List<String> get httpServerUrls => _httpServerUrls;
  String get proxyHost => _proxyHost;
  int get proxyPort => _proxyPort;
  String get proxyUser => _proxyUser;
  String get proxyPass => _proxyPass;
  bool get proxyEnabled => _proxyEnabled;
  List<ProxyConfig> get proxies => _proxies;
  List<BookmarkItem> get bookmarks => _bookmarks;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  String get downloadDir => _downloadDir;
  String get preferredDownloadMethod => _preferredDownloadMethod;

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const compileTimeUrl = String.fromEnvironment('BACKEND_URL', defaultValue: '');
      final loadedUrl = prefs.getString(keyBackendUrl);
      if (compileTimeUrl.isNotEmpty && (loadedUrl == null || loadedUrl == 'http://localhost:3000')) {
        _backendUrl = compileTimeUrl;
      } else {
        _backendUrl = loadedUrl ?? (compileTimeUrl.isNotEmpty ? compileTimeUrl : 'http://localhost:3000');
      }
      _httpServerUrl = prefs.getString(keyHttpServerUrl) ?? defaultHttpServer;
      final urls = prefs.getStringList(keyHttpServerUrls);
      if (urls != null && urls.isNotEmpty) {
        _httpServerUrls = urls;
      } else {
        _httpServerUrls = [defaultHttpServer];
      }
      _proxyHost = prefs.getString(keyProxyHost) ?? defaultProxyHost;
      _proxyPort = prefs.getInt(keyProxyPort) ?? defaultProxyPort;
      _proxyUser = prefs.getString(keyProxyUser) ?? defaultProxyUser;
      _proxyPass = prefs.getString(keyProxyPass) ?? defaultProxyPass;
      _proxyEnabled = prefs.getBool(keyProxyEnabled) ?? true;
      final proxyJsonList = prefs.getStringList(keyProxies);
      if (proxyJsonList != null && proxyJsonList.isNotEmpty) {
        _proxies = proxyJsonList
            .map((s) => ProxyConfig.fromJson(jsonDecode(s) as Map<String, dynamic>))
            .toList();
      } else {
        _proxies = [
          ProxyConfig(
            host: defaultProxyHost,
            port: defaultProxyPort,
            username: defaultProxyUser,
            password: defaultProxyPass,
          )
        ];
      }
      _maxConcurrentDownloads = prefs.getInt(keyMaxConcurrentDownloads) ?? 3;
      _downloadDir = prefs.getString(keyDownloadDir) ?? 'downloads';
      _preferredDownloadMethod = prefs.getString(keyPreferredDownloadMethod) ?? 'prompt';
      final bookmarkStrings = prefs.getStringList('bookmarks');
      if (bookmarkStrings != null) {
        _bookmarks = bookmarkStrings
            .map((s) => BookmarkItem.fromJson(jsonDecode(s) as Map<String, dynamic>))
            .toList();
      } else {
        _bookmarks = [];
      }
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

  Future<void> addHttpServerUrl(String url) async {
    if (!url.endsWith('/')) {
      url += '/';
    }
    if (!_httpServerUrls.contains(url)) {
      _httpServerUrls.add(url);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(keyHttpServerUrls, _httpServerUrls);
      notifyListeners();
    }
  }

  Future<void> removeHttpServerUrl(String url) async {
    if (_httpServerUrls.length > 1) {
      _httpServerUrls.remove(url);
      if (_httpServerUrl == url) {
        _httpServerUrl = _httpServerUrls.first;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(keyHttpServerUrl, _httpServerUrl);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(keyHttpServerUrls, _httpServerUrls);
      notifyListeners();
    }
  }

  Future<void> selectHttpServerUrl(String url) async {
    if (_httpServerUrls.contains(url)) {
      _httpServerUrl = url;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyHttpServerUrl, _httpServerUrl);
      notifyListeners();
    }
  }

  Future<void> addProxy(ProxyConfig proxy) async {
    if (!_proxies.contains(proxy)) {
      _proxies.add(proxy);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(keyProxies, _proxies.map((p) => jsonEncode(p.toJson())).toList());
      notifyListeners();
    }
  }

  Future<void> removeProxy(ProxyConfig proxy) async {
    if (_proxies.length > 1) {
      _proxies.remove(proxy);
      final active = ProxyConfig(
        host: _proxyHost,
        port: _proxyPort,
        username: _proxyUser,
        password: _proxyPass,
      );
      if (active == proxy) {
        final first = _proxies.first;
        _proxyHost = first.host;
        _proxyPort = first.port;
        _proxyUser = first.username;
        _proxyPass = first.password;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(keyProxyHost, _proxyHost);
        await prefs.setInt(keyProxyPort, _proxyPort);
        await prefs.setString(keyProxyUser, _proxyUser);
        await prefs.setString(keyProxyPass, _proxyPass);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(keyProxies, _proxies.map((p) => jsonEncode(p.toJson())).toList());
      notifyListeners();
    }
  }

  Future<void> selectProxy(ProxyConfig proxy) async {
    if (_proxies.contains(proxy)) {
      _proxyHost = proxy.host;
      _proxyPort = proxy.port;
      _proxyUser = proxy.username;
      _proxyPass = proxy.password;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyProxyHost, _proxyHost);
      await prefs.setInt(keyProxyPort, _proxyPort);
      await prefs.setString(keyProxyUser, _proxyUser);
      await prefs.setString(keyProxyPass, _proxyPass);
      notifyListeners();
    }
  }

  Future<void> toggleBookmark(String name, String path) async {
    final item = BookmarkItem(name: name, path: path);
    if (_bookmarks.contains(item)) {
      _bookmarks.remove(item);
    } else {
      _bookmarks.add(item);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bookmarks', _bookmarks.map((b) => jsonEncode(b.toJson())).toList());
    notifyListeners();
  }
}
