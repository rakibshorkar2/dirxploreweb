import 'dart:ui';
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

// ==========================================
// CORE UI HELPERS (GLASS & ANIMATIONS)
// ==========================================

class GlassBackground extends StatefulWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Stack(
          children: [
            // Dark base background
            Container(
              color: const Color(0xFF030308),
            ),
            // Glowing blob 1 (deep indigo/blue) - Top Left moving down-right
            Positioned(
              top: -120 + (value * 220),
              left: -120 + (value * 180),
              width: 500,
              height: 500,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.indigoAccent.withOpacity(0.16),
                      Colors.indigoAccent.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Glowing blob 2 (emerald/teal) - Bottom Right moving up-left
            Positioned(
              bottom: -80 - (value * 180),
              right: -80 + (value * 220),
              width: 550,
              height: 550,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.tealAccent.withOpacity(0.10),
                      Colors.tealAccent.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Glowing blob 3 (deep purple/magenta) - Mid Right moving left
            Positioned(
              top: 250 - (value * 120),
              right: -120 + (value * 140),
              width: 400,
              height: 400,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purpleAccent.withOpacity(0.12),
                      Colors.purpleAccent.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Glowing blob 4 (soft violet) - Center left
            Positioned(
              top: 450 + (value * 100),
              left: -100 - (value * 50),
              width: 380,
              height: 380,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.deepPurpleAccent.withOpacity(0.12),
                      Colors.deepPurpleAccent.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            widget.child,
          ],
        );
      },
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 25.0,
    this.opacity = 0.05,
    this.borderRadius = 20.0,
    this.border,
    this.padding,
    this.margin,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: shadow ?? [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              // Elegant sheen: top gradient reflecting down
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(opacity + 0.02),
                  Colors.white.withOpacity(opacity),
                ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 0.8,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;

  const AnimatedPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.95,
  });

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

class FadeInSlide extends StatefulWidget {
  final Widget child;
  final int index;

  const FadeInSlide({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Staggered trigger based on list index
    Future.delayed(Duration(milliseconds: 30 * widget.index), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: FractionalTranslation(
            translation: _slide.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class GlowingPulseIcon extends StatefulWidget {
  const GlowingPulseIcon({super.key});

  @override
  State<GlowingPulseIcon> createState() => _GlowingPulseIconState();
}

class _GlowingPulseIconState extends State<GlowingPulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.tealAccent.withOpacity(0.06),
              border: Border.all(
                color: Colors.tealAccent.withOpacity(0.2),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.tealAccent.withOpacity(0.12 * (_scale.value - 0.5)),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.explore_rounded,
              color: Colors.tealAccent,
              size: 26,
            ),
          ),
        );
      },
    );
  }
}

class RotatingRefreshIcon extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const RotatingRefreshIcon({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<RotatingRefreshIcon> createState() => _RotatingRefreshIconState();
}

class _RotatingRefreshIconState extends State<RotatingRefreshIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isLoading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RotatingRefreshIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: RotationTransition(
        turns: _controller,
        child: const Icon(Icons.refresh_rounded, color: Colors.white70),
      ),
      onPressed: widget.onPressed,
    );
  }
}

// ==========================================
// TRANSITIONAL GLASS APP COMPONENTS
// ==========================================

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;

  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.06),
                width: 0.8,
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            title: title,
            actions: actions,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class GlassBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: GlassContainer(
          borderRadius: 24,
          opacity: 0.08,
          blur: 20,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.folder_open_outlined, Icons.folder_open_rounded, 'Browse'),
              _buildNavItem(1, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final isActive = currentIndex == index;
    return AnimatedPressable(
      scaleFactor: 0.9,
      onTap: () => onTap(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? Colors.tealAccent.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isActive ? activeIcon : inactiveIcon,
                color: isActive ? Colors.tealAccent : Colors.grey[400],
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.tealAccent : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showGlassDialog({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.65),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) => builder(context),
    transitionBuilder: (context, anim1, anim2, child) {
      final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: curve,
        child: FadeTransition(
          opacity: anim1,
          child: child,
        ),
      );
    },
  );
}

class GlassAlertDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  const GlassAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassContainer(
        borderRadius: 24,
        opacity: 0.08,
        blur: 30,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// APP INITIALIZATION
// ==========================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    if (!settings.isLoaded) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: GlassBackground(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Colors.tealAccent, Colors.deepPurpleAccent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.tealAccent.withOpacity(0.25),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.explore_rounded, color: Colors.black, size: 36),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Colors.tealAccent),
                ],
              ),
            ),
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
          scaffoldBackgroundColor: Colors.transparent, // transparent to let background gradient shine through
          colorScheme: const ColorScheme.dark(
            primary: Colors.deepPurpleAccent,
            secondary: Colors.tealAccent,
            surface: Color(0x18FFFFFF),
            onPrimary: Colors.white,
            onSecondary: Colors.black,
            onSurface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
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
      backgroundColor: Colors.transparent,
      extendBody: true, // Content will render behind the bottom bar
      body: GlassBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

// ==========================================
// BROWSE PAGE (EXPLORER)
// ==========================================

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
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text(
          settings.httpServerUrl,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: Colors.tealAccent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
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
          RotatingRefreshIcon(
            isLoading: _isLoading,
            onPressed: () => _loadDirectory(_currentPath),
          ),
        ],
      ),
      body: Column(
        children: [
          // Path breadcrumbs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.8),
              ),
            ),
            child: Row(
              children: [
                AnimatedPressable(
                  onTap: _navigateHome,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.home_rounded, color: Colors.tealAccent, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      _currentPath.isEmpty ? 'Root' : _currentPath,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                if (_currentPath.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  AnimatedPressable(
                    onTap: _navigateUp,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.deepPurpleAccent, size: 18),
                    ),
                  ),
                ]
              ],
            ),
          ),

          // Bookmarks chip view
          if (settings.bookmarks.isNotEmpty)
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black.withOpacity(0.15),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  const Icon(Icons.bookmarks_outlined, color: Colors.tealAccent, size: 18),
                  const SizedBox(width: 12),
                  ...settings.bookmarks.map((bookmark) {
                    final isCurrent = _currentPath == bookmark.path;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: AnimatedPressable(
                        scaleFactor: 0.94,
                        onTap: () {
                          _loadDirectory(bookmark.path);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isCurrent
                                ? Colors.tealAccent.withOpacity(0.20)
                                : Colors.white.withOpacity(0.04),
                            border: Border.all(
                              color: isCurrent
                                  ? Colors.tealAccent.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.08),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                bookmark.name,
                                style: TextStyle(
                                  color: isCurrent ? Colors.tealAccent : Colors.white70,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  settings.toggleBookmark(bookmark.name, bookmark.path);
                                },
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 13,
                                  color: isCurrent ? Colors.tealAccent : Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Search and Sort controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: GlassContainer(
                    borderRadius: 30,
                    opacity: 0.04,
                    blur: 15,
                    border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search files/folders...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _applyFiltersAndSorting();
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort, color: Colors.deepPurpleAccent),
                  tooltip: 'Sort settings',
                  color: const Color(0xFF1E1E2C),
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
                ? const Center(child: GlowingPulseIcon())
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
                              const SizedBox(height: 20),
                              AnimatedPressable(
                                onTap: () => _loadDirectory(_currentPath),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurpleAccent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.deepPurpleAccent.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
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
                        : ListView.builder(
                            itemCount: _filteredItems.length,
                            padding: const EdgeInsets.only(bottom: 120), // padded to clear bottom navigation floating bar
                            itemBuilder: (context, index) {
                              final item = _filteredItems[index];
                              final fileColor = item.isDirectory ? Colors.cyanAccent : Colors.indigoAccent;
                              final icon = item.isDirectory ? Icons.folder_rounded : Icons.insert_drive_file_rounded;

                              return FadeInSlide(
                                index: index,
                                child: AnimatedPressable(
                                  scaleFactor: 0.97,
                                  onTap: () {
                                    if (item.isDirectory) {
                                      _loadDirectory(item.path);
                                    } else {
                                      _showFilePopup(item);
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.05),
                                        width: 0.8,
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.04),
                                          Colors.white.withOpacity(0.01),
                                        ],
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              // Glowing soft box around folder/file icons
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: fileColor.withOpacity(0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    icon,
                                                    color: fileColor,
                                                    size: 22,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.name,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (!item.isDirectory) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${_formatBytes(item.size)}  •  ${_formatDate(item.modified)}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey[400],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Icon(
                                                item.isDirectory ? Icons.chevron_right_rounded : Icons.download_rounded,
                                                color: Colors.white38,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _showFilePopup(DirectoryItem item) {
    showGlassDialog(
      context: context,
      builder: (context) {
        return GlassAlertDialog(
          title: Row(
            children: [
              const Icon(Icons.insert_drive_file_rounded, color: Colors.tealAccent, size: 26),
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
            const SizedBox(width: 8),
            AnimatedPressable(
              onTap: () {
                Navigator.pop(context);
                _triggerDirectDownload(item);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.tealAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_rounded, size: 18, color: Colors.black),
                    SizedBox(width: 6),
                    Text(
                      'Save to Device',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13),
                    ),
                  ],
                ),
              ),
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

// ==========================================
// SETTINGS PAGE
// ==========================================

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

    showGlassDialog(
      context: context,
      builder: (context) {
        return GlassAlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings_input_antenna_rounded, color: Colors.tealAccent, size: 24),
              SizedBox(width: 10),
              Text(
                'Add Proxy Config',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Form(
            key: dialogFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassTextField(
                    controller: hostCtrl,
                    labelText: 'Proxy Hostname / IP',
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: portCtrl,
                    labelText: 'Port',
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      final port = int.tryParse(val);
                      if (port == null || port <= 0 || port > 65535) return 'Invalid Port';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: userCtrl,
                    labelText: 'Username (Optional)',
                  ),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: passCtrl,
                    labelText: 'Password (Optional)',
                    obscureText: true,
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
            const SizedBox(width: 8),
            AnimatedPressable(
              onTap: () async {
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.tealAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListConfigRow({
    required Widget leading,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
        if (!isLast)
          Divider(
            color: Colors.white.withOpacity(0.05),
            height: 1,
            thickness: 0.8,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const GlassAppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0), // bottom padding so that list doesn't overlap the floating navbar
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Backend Server Config
              SettingsGroupCard(
                title: 'Backend Configuration',
                children: [
                  GlassTextField(
                    controller: _backendCtrl,
                    labelText: 'Node.js Backend API URL',
                    hintText: 'e.g. http://localhost:3000',
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Backend URL is required';
                      if (!val.startsWith('http://') && !val.startsWith('https://')) {
                        return 'URL must start with http:// or https://';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. HTTP Directory Server URLs
              SettingsGroupCard(
                title: 'HTTP Directory Server URLs',
                children: [
                  if (settings.httpServerUrls.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No server URLs configured.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    )
                  else
                    ...settings.httpServerUrls.map((url) {
                      final isActive = settings.httpServerUrl == url;
                      final isLast = settings.httpServerUrls.last == url;
                      return _buildListConfigRow(
                        isLast: isLast,
                        leading: Switch(
                          value: isActive,
                          onChanged: (val) async {
                            if (val) {
                              final api = Provider.of<ApiService>(context, listen: false);
                              await settings.selectHttpServerUrl(url);
                              await api.syncConfig();
                            }
                          },
                          activeColor: Colors.tealAccent,
                        ),
                        title: url,
                        trailing: settings.httpServerUrls.length > 1
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () async {
                                  final api = Provider.of<ApiService>(context, listen: false);
                                  await settings.removeHttpServerUrl(url);
                                  await api.syncConfig();
                                },
                              )
                            : null,
                      );
                    }),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GlassTextField(
                          controller: _newServerUrlCtrl,
                          labelText: 'Add New Server URL',
                          hintText: 'e.g. http://172.16.50.4/',
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedPressable(
                        onTap: () async {
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
                        child: Container(
                          height: 48,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.tealAccent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.tealAccent.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Engine Settings
              SettingsGroupCard(
                title: 'Advanced Engine Settings',
                children: [
                  GlassTextField(
                    controller: _downloadDirCtrl,
                    labelText: 'Server Download Storage Path',
                    hintText: 'e.g. downloads',
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Storage path is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: GlassTextField(
                          controller: _concurrencyCtrl,
                          labelText: 'Queue Limit',
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Required';
                            final num = int.tryParse(val);
                            if (num == null || num <= 0 || num > 10) {
                              return 'Enter 1 to 10';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: GlassContainer(
                          borderRadius: 12,
                          opacity: 0.04,
                          blur: 15,
                          padding: EdgeInsets.zero,
                          border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.8),
                          child: DropdownButtonFormField<String>(
                            dropdownColor: const Color(0xFF1E1E2C),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Default Action',
                              labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                              filled: false,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            value: _preferredMethod,
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
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Proxy Config
              SettingsGroupCard(
                title: 'SOCKS5 Proxy Settings',
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Enable SOCKS5 Proxy',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Switch(
                        value: _proxyEnabled,
                        onChanged: (val) {
                          setState(() {
                            _proxyEnabled = val;
                          });
                        },
                        activeColor: Colors.tealAccent,
                      ),
                    ],
                  ),
                  if (_proxyEnabled) ...[
                    const SizedBox(height: 8),
                    Divider(color: Colors.white.withOpacity(0.05), height: 1, thickness: 0.8),
                    const SizedBox(height: 8),
                    ...settings.proxies.map((proxy) {
                      final isActive = settings.proxyHost == proxy.host &&
                          settings.proxyPort == proxy.port &&
                          settings.proxyUser == proxy.username &&
                          settings.proxyPass == proxy.password;
                      final isLast = settings.proxies.last == proxy;
                      return _buildListConfigRow(
                        isLast: isLast,
                        leading: Switch(
                          value: isActive,
                          onChanged: (val) async {
                            if (val) {
                              final api = Provider.of<ApiService>(context, listen: false);
                              await settings.selectProxy(proxy);
                              await api.syncConfig();
                            }
                          },
                          activeColor: Colors.tealAccent,
                        ),
                        title: '${proxy.host}:${proxy.port}',
                        subtitle: proxy.username.isNotEmpty ? 'User: ${proxy.username}' : null,
                        trailing: settings.proxies.length > 1
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () async {
                                  final api = Provider.of<ApiService>(context, listen: false);
                                  await settings.removeProxy(proxy);
                                  await api.syncConfig();
                                },
                              )
                            : null,
                      );
                    }),
                    const SizedBox(height: 12),
                    AnimatedPressable(
                      onTap: _showAddProxyDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.tealAccent.withOpacity(0.4), width: 0.8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 18, color: Colors.tealAccent),
                            SizedBox(width: 8),
                            Text(
                              'Add Proxy Configuration',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),

              // 5. Actions Area
              AnimatedPressable(
                onTap: _saveSettings,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurpleAccent, Colors.purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurpleAccent.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: const Text(
                    'Save & Apply Settings',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // RAKIB Footer
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.tealAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.tealAccent,
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CREATED BY RAKIB',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
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

// ==========================================
// FORM FIELD HELPERS
// ==========================================

class SettingsGroupCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsGroupCard({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8, top: 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.tealAccent,
              letterSpacing: 1.2,
            ),
          ),
        ),
        GlassContainer(
          borderRadius: 20,
          opacity: 0.05,
          blur: 20,
          padding: const EdgeInsets.all(16),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final Icon? prefixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 12,
      opacity: 0.04,
      blur: 15,
      padding: EdgeInsets.zero,
      border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.8),
      child: TextFormField(
        controller: controller,
        validator: validator,
        onChanged: onChanged,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
          prefixIcon: prefixIcon,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
