import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user.dart';
import '../../theme/app_colors.dart';

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
        builder: (ctx, setSt) => _FormDialog(
          title: 'Edit user',
          error: err,
          fields: [
            _DialogField(label: 'Username', controller: userNameCtrl),
            const SizedBox(height: 12),
            _DialogField(label: 'Email', controller: emailCtrl, keyboardType: TextInputType.emailAddress),
          ],
          confirmLabel: 'Save',
          onConfirm: () async {
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
        builder: (ctx, setSt) => _FormDialog(
          title: 'Reset password for ${user.userName}',
          error: err,
          fields: [
            _DialogField(label: 'New password', controller: pwCtrl, obscure: true),
          ],
          confirmLabel: 'Reset',
          onConfirm: () async {
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
        ),
      ),
    );
  }

  void _confirmDelete(AdminUserDto user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete user', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink)),
        content: Text(
          'Permanently delete "${user.userName}" and all their data? This cannot be undone.',
          style: GoogleFonts.plusJakartaSans(color: AppColors.ink2, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.instance.userId;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        titleSpacing: 22,
        title: const Text('Users'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: _CircleIconButton(icon: Icons.refresh, onTap: _load),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.indigo))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : RefreshIndicator(
                  color: AppColors.indigo,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final isCurrentUser = user.id == currentUserId;
                      return _UserRow(
                        user: user,
                        isCurrentUser: isCurrentUser,
                        onEdit: () => _showEditDialog(user),
                        onResetPassword: () => _showResetPasswordDialog(user),
                        onToggleAdmin: () async {
                          try {
                            await ApiClient.instance.updateUserRole(user.id, !user.isAdmin);
                            _load();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(e.toString().replaceFirst('Exception: ', ''))));
                          }
                        },
                        onDelete: () => _confirmDelete(user),
                      );
                    },
                  ),
                ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final AdminUserDto user;
  final bool isCurrentUser;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleAdmin;
  final VoidCallback onDelete;

  const _UserRow({
    required this.user,
    required this.isCurrentUser,
    required this.onEdit,
    required this.onResetPassword,
    required this.onToggleAdmin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.indigoTint, borderRadius: BorderRadius.circular(13)),
            child: Text(
              user.userName.substring(0, 1).toUpperCase(),
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.indigo),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.userName,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser)
                      Text(' (you)', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.faint, fontWeight: FontWeight.w600)),
                    if (user.isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.indigoTint, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          'ADMIN',
                          style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: AppColors.indigo),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.email} · ${user.comboCount} combo${user.comboCount == 1 ? '' : 's'}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.muted),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  onEdit();
                case 'reset':
                  onResetPassword();
                case 'toggle_admin':
                  onToggleAdmin();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'reset', child: Text('Reset password')),
              PopupMenuItem(
                value: 'toggle_admin',
                child: Text(user.isAdmin ? 'Revoke admin' : 'Make admin'),
              ),
              if (!isCurrentUser)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: AppColors.red)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormDialog extends StatelessWidget {
  final String title;
  final List<Widget> fields;
  final String? error;
  final String confirmLabel;
  final VoidCallback onConfirm;

  const _FormDialog({
    required this.title,
    required this.fields,
    required this.error,
    required this.confirmLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...fields,
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.indigo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onConfirm,
          child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;

  const _DialogField({required this.label, required this.controller, this.obscure = false, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.chipBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.line2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.line2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: const BorderSide(color: AppColors.line2)),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 20, color: AppColors.ink2)),
      ),
    );
  }
}
