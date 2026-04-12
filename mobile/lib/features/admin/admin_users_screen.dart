import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<AdminUserDto> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final users = await ApiClient.instance.getAdminUsers();
      if (!mounted) return;
      setState(() { _users = users; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _showEditDialog(AdminUserDto user) {
    final userNameCtrl = TextEditingController(text: user.userName);
    final emailCtrl = TextEditingController(text: user.email);
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Edit User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userNameCtrl,
                decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiClient.instance.updateAdminUser(
                    user.id,
                    userName: userNameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  setSt(() { err = e.toString().replaceFirst('Exception: ', ''); });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(AdminUserDto user) {
    final pwCtrl = TextEditingController();
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Reset password for ${user.userName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pwCtrl,
                decoration: const InputDecoration(
                    labelText: 'New password', border: OutlineInputBorder()),
                obscureText: true,
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (pwCtrl.text.length < 6) {
                  setSt(() { err = 'Min 6 characters.'; });
                  return;
                }
                try {
                  await ApiClient.instance.resetUserPassword(user.id, pwCtrl.text);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password reset.')));
                } catch (e) {
                  setSt(() { err = e.toString().replaceFirst('Exception: ', ''); });
                }
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(AdminUserDto user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Permanently delete "${user.userName}" and all their data? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiClient.instance.deleteUser(user.id);
                _load();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.instance.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final isCurrentUser = user.id == currentUserId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade50,
                          child: Text(
                            user.userName.substring(0, 1).toUpperCase(),
                            style: TextStyle(color: Colors.indigo.shade700),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(user.userName,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (isCurrentUser)
                              Text(' (you)',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500])),
                            if (user.isAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Admin',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.indigo.shade700,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                            '${user.email} · ${user.comboCount} combo${user.comboCount == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 12)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            switch (action) {
                              case 'edit':
                                _showEditDialog(user);
                              case 'reset':
                                _showResetPasswordDialog(user);
                              case 'toggle_admin':
                                try {
                                  await ApiClient.instance
                                      .updateUserRole(user.id, !user.isAdmin);
                                  _load();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(e
                                          .toString()
                                          .replaceFirst('Exception: ', ''))));
                                }
                              case 'delete':
                                _confirmDelete(user);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'reset', child: Text('Reset password')),
                            PopupMenuItem(
                              value: 'toggle_admin',
                              child: Text(
                                  user.isAdmin ? 'Revoke admin' : 'Make admin'),
                            ),
                            if (!isCurrentUser)
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete',
                                      style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
