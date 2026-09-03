import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/combo.dart';
import '../../theme/app_colors.dart';
import '../../widgets/combo_card.dart';
import '../../widgets/display_options.dart';

class CombosScreen extends StatefulWidget {
  final bool initialDoneOnly;

  const CombosScreen({super.key, this.initialDoneOnly = false});

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
  bool _doneOnly = false;
  final _searchCtrl = TextEditingController();
  String _search = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _doneOnly = widget.initialDoneOnly;
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
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    setState(() => _search = v);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadPublic();
      if (_authed) _loadMine();
    });
  }

  void _loadPublic() {
    final future = ApiClient.instance.getPublicCombos(search: _search.isEmpty ? null : _search);
    setState(() { _publicFuture = future; });
    future.then((r) {
      if (mounted) setState(() => _publicCount = r.totalCount);
    });
  }

  void _loadMine() {
    final future = ApiClient.instance.getMyCombos(search: _search.isEmpty ? null : _search);
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
            .where((c) => !_doneOnly || c.isCompleted)
            .toList();
        if (items.isEmpty) return Center(child: _doneOnly ? _emptyState(Icons.check_circle_outline, "You haven't marked any of these as done yet.") : emptyWidget);
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
        final q = _search.toLowerCase();
        final items = (snap.data ?? [])
            .where((c) => !_doneOnly || c.isCompleted)
            .where((c) =>
                q.isEmpty ||
                (c.name ?? c.displayText).toLowerCase().contains(q) ||
                (c.ownerUserName ?? '').toLowerCase().contains(q))
            .toList();
        if (items.isEmpty) return Center(child: _doneOnly ? _emptyState(Icons.check_circle_outline, "You haven't marked any of these as done yet.") : emptyWidget);
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

  Widget _doneFilterChip() {
    return GestureDetector(
      onTap: () => setState(() => _doneOnly = !_doneOnly),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _doneOnly ? AppColors.indigo : AppColors.chipBg,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _doneOnly ? Icons.check_circle : Icons.check_circle_outline,
              size: 14,
              color: _doneOnly ? Colors.white : AppColors.ink2,
            ),
            const SizedBox(width: 4),
            Text(
              'Done',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _doneOnly ? Colors.white : AppColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisplaySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                  child: Text(
                    'Display',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                  child: buildDisplayOptionsSection(onChanged: () => setSt(() => setState(() {}))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
            padding: const EdgeInsets.only(right: 8),
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
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: _AppBarIconButton(
              icon: Icons.add,
              gradient: true,
              onTap: () => context.push('/combos/create').then((_) {
                if (mounted) {
                  _loadPublic();
                  if (_authed) _loadMine();
                }
              }),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
              child: _Segmented(
                labels: segments,
                selectedIndex: _tabController.index,
                onSelected: (i) => _tabController.animateTo(i),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: TextField(
                controller: _searchCtrl,
                autocorrect: false,
                enableSuggestions: false,
                style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Search combos…',
                  hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.faint, fontWeight: FontWeight.w600),
                  prefixIcon: const Icon(Icons.search, color: AppColors.faint),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.line2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.faint),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_authed)
                    _doneFilterChip()
                  else
                    const SizedBox.shrink(),
                  GestureDetector(
                    onTap: _showDisplaySheet,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.tune, size: 18, color: AppColors.ink2),
                    ),
                  ),
                ],
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
  final bool gradient;
  const _AppBarIconButton({required this.icon, required this.onTap, this.gradient = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: gradient ? Colors.transparent : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: gradient ? BorderSide.none : const BorderSide(color: AppColors.line2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: gradient ? AppColors.grad : null,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 20, color: gradient ? Colors.white : AppColors.ink2),
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
