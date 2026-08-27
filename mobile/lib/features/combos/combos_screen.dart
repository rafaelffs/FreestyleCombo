import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/combo.dart';
import '../../theme/app_colors.dart';
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

  int? _publicCount;
  int? _mineCount;

  @override
  void initState() {
    super.initState();
    final tabCount = _authed ? 3 : 1;
    _tabController = TabController(length: tabCount, vsync: this, initialIndex: _authed ? 1 : 0);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
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

  void _loadPublic() {
    final future = ApiClient.instance.getPublicCombos();
    setState(() { _publicFuture = future; });
    future.then((r) {
      if (mounted) setState(() => _publicCount = r.totalCount);
    });
  }

  void _loadMine() {
    final future = ApiClient.instance.getMyCombos();
    setState(() { _mineFuture = future; });
    future.then((r) {
      if (mounted) setState(() => _mineCount = r.totalCount);
    });
  }

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
          return const Center(child: CircularProgressIndicator(color: AppColors.indigo));
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
          return const Center(child: CircularProgressIndicator(color: AppColors.indigo));
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.red),
            const SizedBox(height: 8),
            Text(message, style: GoogleFonts.plusJakartaSans(color: AppColors.muted)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.indigo),
              onPressed: onRefresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );

  Widget _emptyState(IconData icon, String message, {String? ctaLabel, VoidCallback? onCta}) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.faint),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
          if (ctaLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: onCta,
                child: Text(ctaLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ],
      );

  Widget _listView(List<ComboDto> items, bool showActions, VoidCallback onRefresh) =>
      RefreshIndicator(
        color: AppColors.indigo,
        onRefresh: () async => onRefresh(),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
          itemCount: items.length,
          itemBuilder: (_, i) => ComboCard(
            combo: items[i],
            showActions: showActions,
            onRefresh: onRefresh,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final segments = [
      'Public',
      if (_authed) 'Mine',
      if (_authed) 'Favourites',
    ];

    final subtitleParts = <String>[
      if (_publicCount != null) '$_publicCount public',
      if (_authed && _mineCount != null) '$_mineCount yours',
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        titleSpacing: 22,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Combos'),
                  if (subtitleParts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitleParts.join(' · '),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: _AppBarIconButton(
              icon: Icons.refresh,
              onTap: () {
                _loadPublic();
                if (_authed) {
                  _loadMine();
                  _loadFavourites();
                }
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
              child: _Segmented(
                labels: segments,
                selectedIndex: _tabController.index,
                onSelected: (i) => _tabController.animateTo(i),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPagedList(
                    _publicFuture,
                    _authed,
                    _loadPublic,
                    _emptyState(Icons.public_off, 'No public combos yet.'),
                  ),
                  if (_authed)
                    _buildPagedList(
                      _mineFuture,
                      true,
                      _loadMine,
                      _emptyState(
                        Icons.bookmark_border,
                        "You haven't created any combos yet.",
                        ctaLabel: 'Create your first combo',
                        onCta: () => context.push('/combos/create').then((_) {
                          if (mounted) _loadMine();
                        }),
                      ),
                      filterPublic: true,
                    ),
                  if (_authed)
                    _buildSimpleList(
                      _favouritesFuture,
                      true,
                      _loadFavourites,
                      _emptyState(Icons.favorite_border, "You haven't favourited any combos yet."),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.line2),
          ),
          child: Icon(icon, size: 20, color: AppColors.ink2),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _Segmented({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E6F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: i == selectedIndex
                        ? [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.12),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: i == selectedIndex ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
