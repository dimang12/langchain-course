import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/notifications_client.dart';
import '../../../shared/theme/glass_theme.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../agents/providers/agents_provider.dart';
import '../../agents/screens/today_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calendar/screens/calendar_screen.dart';
import '../../meetings/providers/meetings_provider.dart';
import '../../todos/screens/todos_screen.dart';
import '../../knowledge/screens/goals_screen.dart';
import '../widgets/nav_rail.dart';
import '../widgets/tree_sidebar.dart';
import '../widgets/content_tabs.dart';
import '../widgets/floating_chat.dart';
import '../providers/workspace_provider.dart';
import '../providers/tab_provider.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  int _navIndex = 0;
  double _sidebarWidth = 280;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;
  StreamSubscription<Map<String, dynamic>>? _notificationsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initNotifications());
  }

  void _initNotifications() {
    final auth = ref.read(authProvider);
    final token = auth.user?.accessToken;
    if (token == null) return;

    notificationsClient.connect(token);

    _notificationsSub = notificationsClient.events.listen((event) {
      if (!mounted) return;
      final type = event['type'];
      if (type == 'brief_ready') {
        ref.read(agentsProvider.notifier).loadRuns();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wb_sunny, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Your daily brief is ready'),
              ],
            ),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => setState(() => _navIndex = 4),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _notificationsSub?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().isEmpty) {
        setState(() => _searchResults = []);
        return;
      }
      try {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.dio.get('/workspace/search', queryParameters: {'q': query});
        if (mounted) {
          setState(() {
            _searchResults = (response.data as List).map((e) => e as Map<String, dynamic>).toList();
          });
        }
      } catch (_) {}
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    if (!isCtrl) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      ref.read(workspaceProvider.notifier).createNode('Untitled.md', 'file', fileType: 'md', content: '');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      setState(() => _navIndex = 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyW) {
      final activeTab = ref.read(tabProvider).activeTab;
      if (activeTab != null) ref.read(tabProvider.notifier).closeTab(activeTab.id);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyS) {
      final tabState = ref.read(tabProvider);
      final tab = tabState.activeTab;
      if (tab != null && tab.nodeId != null && tab.isModified == true) {
        final content = tabState.contentCache[tab.nodeId!];
        if (content != null) ref.read(tabProvider.notifier).saveContent(tab.nodeId!, content);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(navIndexProvider, (prev, next) {
      if (next != _navIndex) setState(() => _navIndex = next);
    });
    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            // Animated background with blobs
            const Positioned.fill(child: AnimatedBackground()),
            // App shell
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 800;
                    return Stack(
                      children: [
                        Row(
                          children: [
                            // Glass nav rail
                            GlassPanel(
                              child: WorkspaceNavRail(
                                selectedIndex: _navIndex,
                                onSelected: (index) {
                                  if (index == 10) { context.push('/settings'); return; }
                                  if (index == 2) {
                                    ref.read(chatVisibleProvider.notifier).state = !ref.read(chatVisibleProvider);
                                    return;
                                  }
                                  setState(() => _navIndex = index);
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Glass sidebar
                            if (isWide) ...[
                              if (_navIndex == 0)
                                GlassPanel(
                                  child: TreeSidebar(
                                    width: _sidebarWidth,
                                    onWidthChanged: (w) => setState(() => _sidebarWidth = w),
                                  ),
                                ),
                              if (_navIndex == 1) GlassPanel(child: _buildSearchSidebar()),
                              if (_navIndex == 3) GlassPanel(child: _buildToolsSidebar()),
                              if (_navIndex == 0 || _navIndex == 1 || _navIndex == 3)
                                const SizedBox(width: 14),
                            ],
                            // Glass main area
                            Expanded(
                              child: GlassPanel(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(GlassTheme.panelRadius),
                                  child: _navIndex == 4
                                      ? const TodayScreen()
                                      : _navIndex == 5
                                          ? const GoalsScreen()
                                          : _navIndex == 6
                                              ? const CalendarScreen()
                                              : _navIndex == 7
                                                  ? const TodosScreen()
                                                  : const ContentTabs(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const FloatingChatWindow(),
                        const FloatingChatFAB(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSidebar() {
    return SizedBox(
      width: 260,
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search files...',
                      hintStyle: TextStyle(fontSize: 13, color: GlassTheme.ink3),
                      prefixIcon: Icon(Icons.search, size: 18, color: GlassTheme.ink3),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13, color: GlassTheme.ink),
                    onChanged: _onSearchChanged,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  InkWell(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchResults = []);
                    },
                    child: const Icon(Icons.close, size: 16, color: GlassTheme.ink3),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: GlassTheme.line),
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search, size: 40, color: GlassTheme.ink3.withValues(alpha: 0.4)),
                      const SizedBox(height: 8),
                      Text(
                        _searchController.text.isEmpty ? 'Type to search files' : 'No results found',
                        style: const TextStyle(fontSize: 13, color: GlassTheme.ink3),
                      ),
                    ]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final item = _searchResults[index];
                      return InkWell(
                        onTap: () {
                          ref.read(tabProvider.notifier).openFileTab(
                            item['id'] as String,
                            item['name'] as String,
                            item['file_type'] as String?,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.description, size: 16, color: GlassTheme.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item['name'] as String,
                                  style: const TextStyle(fontSize: 13, color: GlassTheme.ink),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item['file_type'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: GlassTheme.accentSoft.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (item['file_type'] as String).toUpperCase(),
                                    style: const TextStyle(fontSize: 9, color: GlassTheme.accentDeep),
                                  ),
                                ),
                            ],
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

  Widget _buildToolsSidebar() {
    final tools = [
      ('read_file', 'Read workspace file', Icons.description),
      ('create_file', 'Create new file', Icons.note_add),
      ('search_files', 'Search across workspace', Icons.search),
      ('list_folder', 'List folder contents', Icons.folder_open),
    ];
    return SizedBox(
      width: 260,
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            child: const Text(
              'TOOLS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: GlassTheme.ink3),
            ),
          ),
          const Divider(height: 1, color: GlassTheme.line),
          ...tools.map((t) => ListTile(
                leading: Icon(t.$3, color: GlassTheme.accent, size: 20),
                title: Text(t.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.ink)),
                subtitle: Text(t.$2, style: const TextStyle(fontSize: 11, color: GlassTheme.ink3)),
                dense: true,
              )),
          const Divider(color: GlassTheme.line),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Tools are used automatically by the AI when you ask questions in chat.',
              style: TextStyle(fontSize: 11, color: GlassTheme.ink3),
            ),
          ),
        ],
      ),
    );
  }
}
