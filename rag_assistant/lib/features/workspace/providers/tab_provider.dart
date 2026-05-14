import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/tab_model.dart';

class TabState {
  final List<TabModel> tabs;
  final String? activeTabId;
  final Map<String, String> contentCache;

  const TabState({this.tabs = const [], this.activeTabId, this.contentCache = const {}});

  TabModel? get activeTab {
    if (activeTabId == null) return null;
    try {
      return tabs.firstWhere((t) => t.id == activeTabId);
    } catch (_) {
      return null;
    }
  }
}

class TabNotifier extends StateNotifier<TabState> {
  final ApiClient _apiClient;

  TabNotifier(this._apiClient) : super(const TabState());

  void openFileTab(String nodeId, String title, String? fileType) {
    final existing = state.tabs.where((t) => t.nodeId == nodeId).toList();
    if (existing.isNotEmpty) {
      state = TabState(tabs: state.tabs, activeTabId: existing.first.id, contentCache: state.contentCache);
      return;
    }
    final tab = TabModel(id: 'tab_${DateTime.now().millisecondsSinceEpoch}', nodeId: nodeId, type: 'file', title: title, fileType: fileType);
    state = TabState(tabs: [...state.tabs, tab], activeTabId: tab.id, contentCache: state.contentCache);
  }

  void openChatTab() {
    final existing = state.tabs.where((t) => t.type == 'chat').toList();
    if (existing.isNotEmpty) {
      state = TabState(tabs: state.tabs, activeTabId: existing.first.id, contentCache: state.contentCache);
      return;
    }
    final tab = TabModel(id: 'tab_chat', type: 'chat', title: 'AI Chat');
    state = TabState(tabs: [...state.tabs, tab], activeTabId: tab.id, contentCache: state.contentCache);
  }

  void closeTab(String tabId) {
    final tab = state.tabs.where((t) => t.id == tabId).firstOrNull;
    final newTabs = state.tabs.where((t) => t.id != tabId).toList();
    String? newActive = state.activeTabId;
    if (state.activeTabId == tabId) {
      newActive = newTabs.isNotEmpty ? newTabs.last.id : null;
    }
    final newCache = Map<String, String>.from(state.contentCache);
    if (tab?.nodeId != null) newCache.remove(tab!.nodeId!);
    state = TabState(tabs: newTabs, activeTabId: newActive, contentCache: newCache);
  }

  void setActive(String tabId) {
    state = TabState(tabs: state.tabs, activeTabId: tabId, contentCache: state.contentCache);
  }

  void setModified(String tabId, bool modified) {
    final newTabs = state.tabs.map((t) => t.id == tabId ? t.copyWith(isModified: modified) : t).toList();
    state = TabState(tabs: newTabs, activeTabId: state.activeTabId, contentCache: state.contentCache);
  }

  Future<String> loadContent(String nodeId) async {
    if (state.contentCache.containsKey(nodeId)) {
      return state.contentCache[nodeId]!;
    }
    final response = await _apiClient.dio.get('/workspace/node/$nodeId');
    final content = (response.data['content'] as String?) ?? '';
    final newCache = Map<String, String>.from(state.contentCache);
    newCache[nodeId] = content;
    state = TabState(tabs: state.tabs, activeTabId: state.activeTabId, contentCache: newCache);
    return content;
  }

  void updateCachedContent(String nodeId, String content) {
    final newCache = Map<String, String>.from(state.contentCache);
    newCache[nodeId] = content;
    state = TabState(tabs: state.tabs, activeTabId: state.activeTabId, contentCache: newCache);
  }

  Future<void> saveContent(String nodeId, String content) async {
    try {
      await _apiClient.dio.put('/workspace/node/$nodeId', data: {'content': content});
      final tabId = state.tabs.where((t) => t.nodeId == nodeId).firstOrNull?.id;
      if (tabId != null) setModified(tabId, false);
    } catch (_) {}
  }

  /// Drop cached content for a node and bump the open tab's reloadCounter so
  /// the file view re-mounts and fetches fresh content.
  void forceReload(String nodeId) {
    final newCache = Map<String, String>.from(state.contentCache);
    newCache.remove(nodeId);
    final newTabs = state.tabs
        .map((t) => t.nodeId == nodeId ? t.copyWith(reloadCounter: t.reloadCounter + 1) : t)
        .toList();
    state = TabState(tabs: newTabs, activeTabId: state.activeTabId, contentCache: newCache);
  }
}

final tabProvider = StateNotifierProvider<TabNotifier, TabState>((ref) {
  return TabNotifier(ref.read(apiClientProvider));
});
