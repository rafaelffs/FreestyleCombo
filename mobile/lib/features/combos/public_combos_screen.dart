import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/models/combo.dart';
import '../../widgets/combo_card.dart';
import '../../core/auth/auth_service.dart';

class PublicCombosScreen extends StatefulWidget {
  const PublicCombosScreen({super.key});

  @override
  State<PublicCombosScreen> createState() => _PublicCombosScreenState();
}

class _PublicCombosScreenState extends State<PublicCombosScreen> {
  late Future<PagedResult<ComboDto>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ApiClient.instance.getPublicCombos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Combos'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
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
            return const Center(child: Text('No public combos yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => ComboCard(
                combo: items[i],
                showActions: AuthService.instance.isAuthenticated,
                onRefresh: _load,
              ),
            ),
          );
        },
      ),
    );
  }
}
