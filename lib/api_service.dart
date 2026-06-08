import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'settings_provider.dart';

class ApiService {
  final SettingsProvider settings;

  ApiService(this.settings);

  String get _baseUrl => settings.backendUrl;

  Future<void> syncConfig() async {
    final url = Uri.parse('$_baseUrl/api/config');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'httpServerUrl': settings.httpServerUrl,
        'proxyHost': settings.proxyHost,
        'proxyPort': settings.proxyPort,
        'proxyUser': settings.proxyUser,
        'proxyPass': settings.proxyPass,
        'proxyEnabled': settings.proxyEnabled,
        'maxConcurrentDownloads': settings.maxConcurrentDownloads,
        'downloadDir': settings.downloadDir,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to sync settings with backend: ${response.body}');
    }
  }

  Future<List<DirectoryItem>> browse(String path) async {
    // Before browsing, make sure the backend config is synced
    await syncConfig();

    final encodedPath = Uri.encodeComponent(path);
    final url = Uri.parse('$_baseUrl/api/browse?path=$encodedPath');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((json) => DirectoryItem.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to browse directory: ${response.body}');
    }
  }

  Future<List<DownloadItem>> getDownloads() async {
    final url = Uri.parse('$_baseUrl/api/downloads');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((json) => DownloadItem.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load downloads: ${response.body}');
    }
  }

  Future<DownloadItem> addDownload(String name, String urlPath) async {
    // Ensure config is synced
    await syncConfig();

    final url = Uri.parse('$_baseUrl/api/downloads');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'url': urlPath,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 210 || response.statusCode == 201) {
      return DownloadItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to start download: ${response.body}');
    }
  }

  Future<void> pauseDownload(String id) async {
    final url = Uri.parse('$_baseUrl/api/downloads/$id/pause');
    final response = await http.post(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to pause download: ${response.body}');
    }
  }

  Future<void> resumeDownload(String id) async {
    final url = Uri.parse('$_baseUrl/api/downloads/$id/resume');
    final response = await http.post(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to resume download: ${response.body}');
    }
  }

  Future<void> retryDownload(String id) async {
    final url = Uri.parse('$_baseUrl/api/downloads/$id/retry');
    final response = await http.post(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to retry download: ${response.body}');
    }
  }

  Future<void> cancelDownload(String id) async {
    final url = Uri.parse('$_baseUrl/api/downloads/$id/cancel');
    final response = await http.post(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to cancel download: ${response.body}');
    }
  }
}
