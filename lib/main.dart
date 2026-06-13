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
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
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

    final isBookmarked = settings.bookmarks.any((b) => b.path == _currentPath);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.httpServerUrl),
        actions: [
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? Colors.tealAccent : Colors.white,
            ),
            onPressed: () {
              String name = 'Root';
              if (_currentPath.isNotEmpty) {
                final cleanPath = _currentPath.endsWith('/')
                    ? _currentPath.substring(0, _currentPath.length - 1)
                    : _currentPath;
                name = cleanPath.split('/').last;
              }
              settings.toggleBookmark(name, _currentPath);
            },
            tooltip: 'Bookmark current folder',
          ),
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

          // Bookmarks chip view
          if (settings.bookmarks.isNotEmpty)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: const Color(0xFF0A0A0A),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  const Icon(Icons.bookmarks_outlined, color: Colors.tealAccent, size: 20),
                  const SizedBox(width: 8),
                  ...settings.bookmarks.map((bookmark) {
                    final isCurrent = _currentPath == bookmark.path;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InputChip(
                        label: Text(bookmark.name),
                        labelStyle: TextStyle(
                          color: isCurrent ? Colors.black : Colors.white70,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        backgroundColor: isCurrent ? Colors.tealAccent : const Color(0xFF1E1E1E),
                        selectedColor: Colors.tealAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isCurrent ? Colors.tealAccent : Colors.grey[800]!,
                            width: 1,
                          ),
                        ),
                        onPressed: () {
                          _loadDirectory(bookmark.path);
                        },
                        onDeleted: () {
                          settings.toggleBookmark(bookmark.name, bookmark.path);
                        },
                        deleteIcon: Icon(
                          Icons.close,
                          size: 14,
                          color: isCurrent ? Colors.black : Colors.grey,
                        ),
                      ),
                    );
                  }),
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
                                    : const Icon(Icons.download, color: Colors.grey, size: 20),
                                onTap: () {
                                  if (item.isDirectory) {
                                    _loadDirectory(item.path);
                                  } else {
                                    _showFilePopup(item);
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

  void _showFilePopup(DirectoryItem item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.insert_drive_file, color: Colors.tealAccent, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.size != null) ...[
                Text('Size: ${_formatBytes(item.size)}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
              ],
              if (item.modified != null) ...[
                Text('Modified: ${_formatDate(item.modified)}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 6),
              const Text('Would you like to download this file directly to your local device?', style: TextStyle(color: Colors.white60, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _triggerDirectDownload(item);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Save to Device', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _triggerDirectDownload(DirectoryItem item) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
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
}

class CenterTitle {
  static const center = TextAlign.center;
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
  late TextEditingController _newServerUrlCtrl;
  late bool _proxyEnabled;

  late TextEditingController _concurrencyCtrl;
  late TextEditingController _downloadDirCtrl;
  late String _preferredMethod;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _backendCtrl = TextEditingController(text: settings.backendUrl);
    _newServerUrlCtrl = TextEditingController();
    _proxyEnabled = settings.proxyEnabled;

    _concurrencyCtrl = TextEditingController(text: settings.maxConcurrentDownloads.toString());
    _downloadDirCtrl = TextEditingController(text: settings.downloadDir);
    _preferredMethod = settings.preferredDownloadMethod;
  }

  @override
  void dispose() {
    _backendCtrl.dispose();
    _newServerUrlCtrl.dispose();
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

  void _showAddProxyDialog() {
    final hostCtrl = TextEditingController();
    final portCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Proxy Config', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Form(
            key: dialogFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: hostCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Proxy Hostname / IP',
                      labelStyle: TextStyle(color: Colors.grey),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: portCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      labelStyle: TextStyle(color: Colors.grey),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      final port = int.tryParse(val);
                      if (port == null || port <= 0 || port > 65535) return 'Invalid Port';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username (Optional)',
                      labelStyle: TextStyle(color: Colors.grey),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Password (Optional)',
                      labelStyle: TextStyle(color: Colors.grey),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                    ),
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (dialogFormKey.currentState!.validate()) {
                  final settings = Provider.of<SettingsProvider>(context, listen: false);
                  final proxy = ProxyConfig(
                    host: hostCtrl.text.trim(),
                    port: int.parse(portCtrl.text.trim()),
                    username: userCtrl.text,
                    password: passCtrl.text,
                  );
                  final navigator = Navigator.of(context);
                  final api = Provider.of<ApiService>(context, listen: false);
                  await settings.addProxy(proxy);
                  navigator.pop();
                  await api.syncConfig();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

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
              const SizedBox(height: 20),
              const Text(
                'HTTP Directory Server URLs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.tealAccent),
              ),
              const SizedBox(height: 8),
              ...settings.httpServerUrls.map((url) {
                final isActive = settings.httpServerUrl == url;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isActive ? Colors.deepPurpleAccent : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Switch(
                      value: isActive,
                      onChanged: (val) async {
                        if (val) {
                          final api = Provider.of<ApiService>(context, listen: false);
                          await settings.selectHttpServerUrl(url);
                          await api.syncConfig();
                        }
                      },
                      activeThumbColor: Colors.tealAccent,
                      activeTrackColor: Colors.tealAccent.withValues(alpha: 0.5),
                    ),
                    title: Text(
                      url,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white70,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: settings.httpServerUrls.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () async {
                              final api = Provider.of<ApiService>(context, listen: false);
                              await settings.removeHttpServerUrl(url);
                              await api.syncConfig();
                            },
                          )
                        : null,
                  ),
                );
              }),
              const SizedBox(height: 12),
              // Add Server URL inline
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _newServerUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Add New Server URL',
                        hintText: 'e.g. http://172.16.50.4/',
                        filled: true,
                        fillColor: Color(0xFF121212),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final text = _newServerUrlCtrl.text.trim();
                      if (text.isNotEmpty && (text.startsWith('http://') || text.startsWith('https://'))) {
                        final api = Provider.of<ApiService>(context, listen: false);
                        await settings.addHttpServerUrl(text);
                        _newServerUrlCtrl.clear();
                        await api.syncConfig();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid URL starting with http:// or https://'),
                            backgroundColor: Colors.orangeAccent,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Icon(Icons.add),
                  ),
                ],
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
                ...settings.proxies.map((proxy) {
                  final isActive = settings.proxyHost == proxy.host &&
                      settings.proxyPort == proxy.port &&
                      settings.proxyUser == proxy.username &&
                      settings.proxyPass == proxy.password;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isActive ? Colors.deepPurpleAccent : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Switch(
                        value: isActive,
                        onChanged: (val) async {
                          if (val) {
                            final api = Provider.of<ApiService>(context, listen: false);
                            await settings.selectProxy(proxy);
                            await api.syncConfig();
                          }
                        },
                        activeThumbColor: Colors.tealAccent,
                        activeTrackColor: Colors.tealAccent.withValues(alpha: 0.5),
                      ),
                      title: Text(
                        '${proxy.host}:${proxy.port}',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: proxy.username.isNotEmpty
                          ? Text(
                              'User: ${proxy.username}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            )
                          : null,
                      trailing: settings.proxies.length > 1
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () async {
                                final api = Provider.of<ApiService>(context, listen: false);
                                await settings.removeProxy(proxy);
                                await api.syncConfig();
                              },
                            )
                          : null,
                    ),
                  );
                }),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _showAddProxyDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.tealAccent,
                    side: const BorderSide(color: Colors.tealAccent, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Proxy Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Created by RAKIB',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
