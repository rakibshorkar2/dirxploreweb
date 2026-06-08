class DirectoryItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modified;

  DirectoryItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modified,
  });

  factory DirectoryItem.fromJson(Map<String, dynamic> json) {
    return DirectoryItem(
      name: json['name'] as String,
      path: json['path'] as String,
      isDirectory: json['isDirectory'] as bool,
      size: json['size'] as int?,
      modified: json['modified'] != null
          ? DateTime.tryParse(json['modified'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'isDirectory': isDirectory,
      'size': size,
      'modified': modified?.toIso8601String(),
    };
  }
}

class DownloadItem {
  final String id;
  final String name;
  final String url;
  final double progress;
  final double speed; // bytes per second
  final String status; // 'pending', 'downloading', 'paused', 'completed', 'failed'
  final String? eta;
  final int downloadedBytes;
  final int totalBytes;

  DownloadItem({
    required this.id,
    required this.name,
    required this.url,
    required this.progress,
    required this.speed,
    required this.status,
    this.eta,
    required this.downloadedBytes,
    required this.totalBytes,
  });

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      eta: json['eta'] as String?,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
    );
  }

  DownloadItem copyWith({
    String? id,
    String? name,
    String? url,
    double? progress,
    double? speed,
    String? status,
    String? eta,
    int? downloadedBytes,
    int? totalBytes,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      status: status ?? this.status,
      eta: eta ?? this.eta,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}
