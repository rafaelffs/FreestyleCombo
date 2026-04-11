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
  final bool _authed = AuthService.instance.isAuthenticated;

  @override
  void initState() {
    super.initState();
    final initialIndex = _authed ? 1 : 0;
    _tabController = TabController(length: _authed ? 2 : 1, vsync: this, initialIndex: 0)
      ..index = 0;
    if (_authed) {
      _tabController.index = initialIndex;
    }
    _loadPublic();
    if (_authed) _loadMine();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadPublic() {
    setState(() {
      _publicFuture = ApiClient.instance.getPublicCombos();
    });
  }

  void _loadMine() {
    setState(() {
      _mineFuture = ApiClient.instance.getMyCombos();
    });
  }

  Widget _buildList(
    Future<PagedResult<ComboDto>> future,
    bool showActions,
    VoidCallback onRefresh,
    Widget emptyWidget,
  ) {
    return FutureBuilder<PagedResult<ComboDto>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text(snap.error.toString()),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRefresh, child: const Text('Retry')),
              ],
            ),
          );
        }
        final items = snap.data?.items ?? [];
        if (items.isEmpty) return Center(child: emptyWidget);
        return RefreshIndicator(
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(text: 'Public'),
      if (_authed) const Tab(text: 'Mine'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadPublic();
              if (_authed) _loadMine();
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
          _buildList(
            _publicFuture,
            _authed,
            _loadPublic,
            const Text('No public combos yet.'),
          ),
          if (_authed)
            _buildList(
              _mineFuture,
              true,
              _loadMine,
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("You haven't created any combos yet."),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.push('/combos/create').then((_) {
                      if (mounted) _loadMine();
                    }),
                    child: const Text('Create your first combo'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
