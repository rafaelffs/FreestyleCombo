import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/models/combo.dart';
import '../../widgets/combo_card.dart';

class MyCombosScreen extends StatefulWidget {
  const MyCombosScreen({super.key});

  @override
  State<MyCombosScreen> createState() => _MyCombosScreenState();
}

class _MyCombosScreenState extends State<MyCombosScreen> {
  late Future<PagedResult<ComboDto>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ApiClient.instance.getMyCombos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Combos'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/generate'),
        icon: const Icon(Icons.add),
        label: const Text('Generate'),
      ),
      body: FutureBuilder<PagedResult<ComboDto>>(
        future: _future,
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
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            );
          }
          final items = snap.data?.items ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("You haven't generated any combos yet."),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/generate'),
                    child: const Text('Generate your first combo'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => ComboCard(
                combo: items[i],
                showActions: true,
                onRefresh: _load,
              ),
            ),
          );
        },
      ),
    );
  }
}
