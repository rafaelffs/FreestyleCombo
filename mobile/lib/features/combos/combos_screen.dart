import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/combo.dart';
import '../../widgets/combo_card.dart';

class CombosScreen extends StatefulWidget {
  const CombosScreen({super.key});

  @override
  State<CombosScreen> createState() => _CombosScreenState();
}

class _CombosScreenState extends State<CombosScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<PagedResult<ComboDto>> _publicFuture;
  late Future<PagedResult<ComboDto>> _mineFuture;
  late Future<List<ComboDto>> _favouritesFuture;
  final bool _authed = AuthService.instance.isAuthenticated;

  @override
  void initState() {
    super.initState();
    final tabCount = _authed ? 3 : 1;
    _tabController = TabController(length: tabCount, vsync: this, initialIndex: _authed ? 1 : 0);
    _loadPublic();
    if (_authed) {
      _loadMine();
      _loadFavourites();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadPublic() => setState(() {
        _publicFuture = ApiClient.instance.getPublicCombos();
      });

  void _loadMine() => setState(() {
        _mineFuture = ApiClient.instance.getMyCombos();
      });

  void _loadFavourites() => setState(() {
        _favouritesFuture = ApiClient.instance.getFavourites();
      });

  Widget _buildPagedList(
    Future<PagedResult<ComboDto>> future,
    bool showActions,
    VoidCallback onRefresh,
    Widget emptyWidget, {
    bool filterPublic = false,
  }) {
    return FutureBuilder<PagedResult<ComboDto>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _errorView(snap.error.toString(), onRefresh);
        }
        final items = (snap.data?.items ?? [])
            .where((c) => !filterPublic || c.visibility != 'Public')
            .toList();
        if (items.isEmpty) return Center(child: emptyWidget);
        return _listView(items, showActions, onRefresh);
      },
    );
  }

  Widget _buildSimpleList(
    Future<List<ComboDto>> future,
    bool showActions,
    VoidCallback onRefresh,
    Widget emptyWidget,
  ) {
    return FutureBuilder<List<ComboDto>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _errorView(snap.error.toString(), onRefresh);
        }
        final items = snap.data ?? [];
        if (items.isEmpty) return Center(child: emptyWidget);
        return _listView(items, showActions, onRefresh);
      },
    );
  }

  Widget _errorView(String message, VoidCallback onRefresh) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRefresh, child: const Text('Retry')),
          ],
        ),
      );

  Widget _listView(List<ComboDto> items, bool showActions, VoidCallback onRefresh) =>
      RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => ComboCard(
            combo: items[i],
            showActions: showActions,
            onRefresh: onRefresh,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(text: 'Public (All)'),
      if (_authed) const Tab(text: 'Mine'),
      if (_authed) const Tab(text: 'Favourites'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadPublic();
              if (_authed) {
                _loadMine();
                _loadFavourites();
              }
            },
          ),
        ],
        bottom: TabBar(controller: _tabController, tabs: tabs),
      ),
      floatingActionButton: _authed
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/combos/create').then((_) {
                if (mounted) _loadMine();
              }),
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPagedList(
            _publicFuture,
            _authed,
            _loadPublic,
            const Text('No public combos yet.'),
          ),
          if (_authed)
            _buildPagedList(
              _mineFuture,
              true,
              _loadMine,
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("You haven't created any private combos yet."),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.push('/combos/create').then((_) {
                      if (mounted) _loadMine();
                    }),
                    child: const Text('Create your first combo'),
                  ),
                ],
              ),
              filterPublic: true,
            ),
          if (_authed)
            _buildSimpleList(
              _favouritesFuture,
              true,
              _loadFavourites,
              const Text("You haven't favourited any combos yet."),
            ),
        ],
      ),
    );
  }
}
