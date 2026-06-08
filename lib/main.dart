import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings_provider.dart';
import 'download_provider.dart';
import 'api_service.dart';
import 'models.dart';
import 'download_helper.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    // If settings are not loaded yet, show a black screen loader
    if (!settings.isLoaded) {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService(settings)),
        ChangeNotifierProvider(
          create: (ctx) => DownloadProvider(Provider.of<ApiService>(ctx, listen: false)),
        ),
      ],
      child: MaterialApp(
        title: 'DirXplore',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
          colorScheme: const ColorScheme.dark(
            primary: Colors.deepPurpleAccent,
            secondary: Colors.tealAccent,
            surface: Color(0xFF121212),
            onPrimary: Colors.white,
            onSecondary: Colors.black,
            onSurface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          cardTheme: const CardThemeData(
            color: Color(0xFF1E1E1E),
            elevation: 2,
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        home: const MainNavigationScreen(),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DirectoryBrowserPage(),
    const DownloadManagerPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF222222), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.black,
          selectedItemColor: Colors.deepPurpleAccent,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_open),
              label: 'Browse',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.download),
              label: 'Downloads',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// BROWSE PAGE
class DirectoryBrowserPage extends StatefulWidget {
  const DirectoryBrowserPage({super.key});

  @override
  State<DirectoryBrowserPage> createState() => _DirectoryBrowserPageState();
}

class _DirectoryBrowserPageState extends State<DirectoryBrowserPage> {
  String _currentPath = '';
  List<DirectoryItem> _items = [];
  List<DirectoryItem> _filteredItems = [];
  bool _isLoading = false;
  String? _error;

  String _searchQuery = '';
  String _sortBy = 'name'; // 'name', 'size', 'modified'
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDirectory('');
    });
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final items = await apiService.browse(path);
      setState(() {
        _items = items;
        _currentPath = path;
        _applyFiltersAndSorting();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFiltersAndSorting() {
    // Apply search filter
    var list = _items.where((item) {
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Sort: Folders always go first
    list.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int comparison = 0;
      if (_sortBy == 'name') {
        comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else if (_sortBy == 'size') {
        final aSize = a.size ?? 0;
        final bSize = b.size ?? 0;
        comparison = aSize.compareTo(bSize);
      } else if (_sortBy == 'modified') {
        final aMod = a.modified ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bMod = b.modified ?? DateTime.fromMillisecondsSinceEpoch(0);
        comparison = aMod.compareTo(bMod);
      }

      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredItems = list;
    });
  }

  void _navigateUp() {
    if (_currentPath.isEmpty || _currentPath == '/') return;
    final parts = _currentPath.split('/')..removeLast();
    // remove empty strings or handle trailing slash
    if (parts.isNotEmpty && parts.last.isEmpty) {
      parts.removeLast();
    }
    final parent = parts.join('/');
    _loadDirectory(parent);
  }

  void _navigateHome() {
    _loadDirectory('');
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes < 0) return '';
    if (bytes == 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    double val = bytes.toDouble();
    int i = 0;
    while (val >= 1024 && i < suffixes.length - 1) {
      val /= 1024;
      i++;
    }
    return '${val.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.httpServerUrl),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDirectory(_currentPath),
          ),
        ],
      ),
      body: Column(
        children: [
          // Path breadcrumbs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF0F0F0F),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.home, color: Colors.tealAccent),
                  onPressed: _navigateHome,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      _currentPath.isEmpty ? 'Root' : _currentPath,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                if (_currentPath.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, color: Colors.deepPurpleAccent, size: 20),
                    onPressed: _navigateUp,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Up One Level',
                  ),
              ],
            ),
          ),

          // Search and Sort controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search files/folders...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _applyFiltersAndSorting();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort, color: Colors.deepPurpleAccent),
                  tooltip: 'Sort settings',
                  onSelected: (val) {
                    setState(() {
                      if (_sortBy == val) {
                        _sortAscending = !_sortAscending;
                      } else {
                        _sortBy = val;
                        _sortAscending = true;
                      }
                      _applyFiltersAndSorting();
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'name',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'name'
                                ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                : null,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text('Sort by Name'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'size',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'size'
                                ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                : null,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text('Sort by Size'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'modified',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'modified'
                                ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                : null,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text('Sort by Date'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main explorer area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.redAccent),
                                textAlign: CenterTitle.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _loadDirectory(_currentPath),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredItems.isEmpty
                        ? const Center(
                            child: Text(
                              'Empty directory or no search matches',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredItems.length,
                            separatorBuilder: (context, index) => const Divider(
                              color: Color(0xFF1E1E1E),
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final item = _filteredItems[index];
                              return ListTile(
                                leading: Icon(
                                  item.isDirectory ? Icons.folder : Icons.insert_drive_file,
                                  color: item.isDirectory ? Colors.tealAccent : Colors.white60,
                                ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: item.isDirectory
                                    ? null
                                    : Text(
                                        '${_formatBytes(item.size)}  •  ${_formatDate(item.modified)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                trailing: item.isDirectory
                                    ? const Icon(Icons.chevron_right, color: Colors.grey)
                                    : IconButton(
                                        icon: const Icon(Icons.download, color: Colors.deepPurpleAccent),
                                        onPressed: () => _startDownload(item),
                                      ),
                                onTap: () {
                                  if (item.isDirectory) {
                                    _loadDirectory(item.path);
                                  } else {
                                    _startDownload(item);
                                  }
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _startDownload(DirectoryItem item) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    if (settings.preferredDownloadMethod == 'direct') {
      _triggerDirectDownload(item);
    } else if (settings.preferredDownloadMethod == 'server') {
      _triggerServerDownload(item);
    } else {
      // Prompt user with a premium-styled modal dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.download_for_offline, color: Colors.tealAccent, size: 28),
              SizedBox(width: 10),
              Text('Choose Download Method', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'How would you like to download "${item.name}"?',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _triggerDirectDownload(item);
              },
              icon: const Icon(Icons.mobile_screen_share, size: 18),
              label: const Text('Save to Device'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _triggerServerDownload(item);
              },
              icon: const Icon(Icons.dns, size: 18),
              label: const Text('Queue on Server'),
            ),
          ],
        ),
      );
    }
  }

  void _triggerDirectDownload(DirectoryItem item) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    // Direct download URL: http://localhost:3000/api/download/direct?url=...&name=...
    final encodedUrl = Uri.encodeComponent(item.path);
    final encodedName = Uri.encodeComponent(item.name);
    final downloadUrl = '${settings.backendUrl}/api/download/direct?url=$encodedUrl&name=$encodedName';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading "${item.name}" directly to your device storage...'),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 3),
      ),
    );

    triggerDeviceDownload(downloadUrl, item.name);
  }

  void _triggerServerDownload(DirectoryItem item) async {
    final downloadsProvider = Provider.of<DownloadProvider>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Queueing on server: ${item.name}'),
        backgroundColor: Colors.deepPurpleAccent,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      await downloadsProvider.addDownload(item.name, item.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server queue failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

class CenterTitle {
  static const center = TextAlign.center;
}

// DOWNLOAD MANAGER PAGE
class DownloadManagerPage extends StatelessWidget {
  const DownloadManagerPage({super.key});

  String _formatBytesPerSec(double speed) {
    if (speed <= 0) return '0 B/s';
    const suffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    double val = speed;
    int i = 0;
    while (val >= 1024 && i < suffixes.length - 1) {
      val /= 1024;
      i++;
    }
    return '${val.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    double val = bytes.toDouble();
    int i = 0;
    while (val >= 1024 && i < suffixes.length - 1) {
      val /= 1024;
      i++;
    }
    return '${val.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'downloading':
        return Colors.tealAccent;
      case 'completed':
        return Colors.greenAccent;
      case 'failed':
        return Colors.redAccent;
      case 'paused':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DownloadProvider>(context);

    final activeDownloads = provider.downloads
        .where((d) => d.status == 'downloading' || d.status == 'pending' || d.status == 'paused')
        .toList();

    final completedDownloads = provider.downloads
        .where((d) => d.status == 'completed' || d.status == 'failed')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchDownloads(),
          ),
        ],
      ),
      body: provider.isLoading && provider.downloads.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
          : CustomScrollView(
              slivers: [
                if (provider.error != null)
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.red.withAlpha(51),
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(16),
                      child: Text(
                        'Error: ${provider.error}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),

                // Active Queue Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                    child: Text(
                      'Active Downloads (${activeDownloads.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                    ),
                  ),
                ),

                if (activeDownloads.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No active downloads',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = activeDownloads[index];
                        final progressPercent = (item.progress * 100).toStringAsFixed(1);

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      item.status.toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(item.status),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: item.progress,
                                  backgroundColor: Colors.black26,
                                  color: _getStatusColor(item.status),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$progressPercent% (${_formatBytes(item.downloadedBytes)} / ${_formatBytes(item.totalBytes)})',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    Text(
                                      item.status == 'downloading'
                                          ? '${_formatBytesPerSec(item.speed)}  •  ETA: ${item.eta ?? 'N/A'}'
                                          : '',
                                      style: const TextStyle(fontSize: 11, color: Colors.tealAccent),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (item.status == 'downloading')
                                      TextButton.icon(
                                        onPressed: () => provider.pauseDownload(item.id),
                                        icon: const Icon(Icons.pause, size: 16),
                                        label: const Text('Pause'),
                                        style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent),
                                      )
                                    else if (item.status == 'paused')
                                      TextButton.icon(
                                        onPressed: () => provider.resumeDownload(item.id),
                                        icon: const Icon(Icons.play_arrow, size: 16),
                                        label: const Text('Resume'),
                                        style: TextButton.styleFrom(foregroundColor: Colors.tealAccent),
                                      ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => provider.cancelDownload(item.id),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Cancel'),
                                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: activeDownloads.length,
                    ),
                  ),

                // History Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
                    child: Text(
                      'Download History (${completedDownloads.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent),
                    ),
                  ),
                ),

                if (completedDownloads.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No history available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = completedDownloads[index];
                        return ListTile(
                          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            'Size: ${_formatBytes(item.totalBytes)}  •  Status: ${item.status}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.status == 'completed' ? Icons.check_circle : Icons.error,
                                color: _getStatusColor(item.status),
                              ),
                              if (item.status == 'failed')
                                IconButton(
                                  icon: const Icon(Icons.refresh, color: Colors.deepPurpleAccent),
                                  onPressed: () => provider.retryDownload(item.id),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => provider.cancelDownload(item.id),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: completedDownloads.length,
                    ),
                  ),
              ],
            ),
    );
  }
}

// SETTINGS PAGE
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _backendCtrl;
  late TextEditingController _httpServerCtrl;
  late TextEditingController _proxyHostCtrl;
  late TextEditingController _proxyPortCtrl;
  late TextEditingController _proxyUserCtrl;
  late TextEditingController _proxyPassCtrl;
  late bool _proxyEnabled;

  late TextEditingController _concurrencyCtrl;
  late TextEditingController _downloadDirCtrl;
  late String _preferredMethod;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _backendCtrl = TextEditingController(text: settings.backendUrl);
    _httpServerCtrl = TextEditingController(text: settings.httpServerUrl);
    _proxyHostCtrl = TextEditingController(text: settings.proxyHost);
    _proxyPortCtrl = TextEditingController(text: settings.proxyPort.toString());
    _proxyUserCtrl = TextEditingController(text: settings.proxyUser);
    _proxyPassCtrl = TextEditingController(text: settings.proxyPass);
    _proxyEnabled = settings.proxyEnabled;

    _concurrencyCtrl = TextEditingController(text: settings.maxConcurrentDownloads.toString());
    _downloadDirCtrl = TextEditingController(text: settings.downloadDir);
    _preferredMethod = settings.preferredDownloadMethod;
  }

  @override
  void dispose() {
    _backendCtrl.dispose();
    _httpServerCtrl.dispose();
    _proxyHostCtrl.dispose();
    _proxyPortCtrl.dispose();
    _proxyUserCtrl.dispose();
    _proxyPassCtrl.dispose();
    _concurrencyCtrl.dispose();
    _downloadDirCtrl.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);

      try {
        await settings.updateSettings(
          backendUrl: _backendCtrl.text.trim(),
          httpServerUrl: _httpServerCtrl.text.trim(),
          proxyHost: _proxyHostCtrl.text.trim(),
          proxyPort: int.parse(_proxyPortCtrl.text.trim()),
          proxyUser: _proxyUserCtrl.text,
          proxyPass: _proxyPassCtrl.text,
          proxyEnabled: _proxyEnabled,
          maxConcurrentDownloads: int.parse(_concurrencyCtrl.text.trim()),
          downloadDir: _downloadDirCtrl.text.trim(),
          preferredDownloadMethod: _preferredMethod,
        );

        if (!mounted) return;
        // Notify backend of configuration sync
        final api = Provider.of<ApiService>(context, listen: false);
        await api.syncConfig();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved and synchronized!'),
            backgroundColor: Colors.teal,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Server Configuration Section
              const Text(
                'Server Configuration',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.tealAccent),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _backendCtrl,
                decoration: const InputDecoration(
                  labelText: 'Node.js Backend API URL',
                  hintText: 'e.g. http://localhost:3000',
                  filled: true,
                  fillColor: Color(0xFF121212),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Backend URL is required';
                  if (!val.startsWith('http://') && !val.startsWith('https://')) {
                    return 'URL must start with http:// or https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _httpServerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Target HTTP Directory Server URL',
                  hintText: 'e.g. http://172.16.50.4/',
                  filled: true,
                  fillColor: Color(0xFF121212),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'HTTP Server URL is required';
                  if (!val.startsWith('http://') && !val.startsWith('https://')) {
                    return 'URL must start with http:// or https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Advanced Engine Configuration Section
              const Text(
                'Advanced Engine Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.tealAccent),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _downloadDirCtrl,
                decoration: const InputDecoration(
                  labelText: 'Server Download Storage Path',
                  hintText: 'e.g. downloads',
                  filled: true,
                  fillColor: Color(0xFF121212),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Storage path is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _concurrencyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Max Concurrent Queue Downloads',
                        filled: true,
                        fillColor: Color(0xFF121212),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        final num = int.tryParse(val);
                        if (num == null || num <= 0 || num > 10) {
                          return 'Enter number between 1 and 10';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _preferredMethod,
                      decoration: const InputDecoration(
                        labelText: 'Default Download Action',
                        filled: true,
                        fillColor: Color(0xFF121212),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'prompt', child: Text('Ask Every Time')),
                        DropdownMenuItem(value: 'direct', child: Text('Direct to Device')),
                        DropdownMenuItem(value: 'server', child: Text('Queue on Server')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _preferredMethod = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Proxy Configuration Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SOCKS5 Proxy Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                  ),
                  Switch(
                    value: _proxyEnabled,
                    onChanged: (val) {
                      setState(() {
                        _proxyEnabled = val;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_proxyEnabled) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _proxyHostCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Proxy Hostname / IP',
                          filled: true,
                          fillColor: Color(0xFF121212),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (_proxyEnabled && (val == null || val.isEmpty)) {
                            return 'Proxy hostname is required when enabled';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _proxyPortCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          filled: true,
                          fillColor: Color(0xFF121212),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (_proxyEnabled) {
                            if (val == null || val.isEmpty) return 'Required';
                            final port = int.tryParse(val);
                            if (port == null || port <= 0 || port > 65535) {
                              return 'Invalid';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _proxyUserCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Username (Optional)',
                          filled: true,
                          fillColor: Color(0xFF121212),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _proxyPassCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Password (Optional)',
                          filled: true,
                          fillColor: Color(0xFF121212),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save & Apply Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
