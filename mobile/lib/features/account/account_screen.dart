import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  ProfileDto? _profile;
  bool _loading = true;
  String? _error;

  // Edit profile
  final _userNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _profileSaving = false;
  String? _profileError;
  String? _profileSuccess;

  // Change password
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _pwSaving = false;
  String? _pwError;
  String? _pwSuccess;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userNameCtrl.dispose();
    _emailCtrl.dispose();
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await ApiClient.instance.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _userNameCtrl.text = profile.userName;
        _emailCtrl.text = profile.email;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final newUserName = _userNameCtrl.text.trim();
    final newEmail = _emailCtrl.text.trim();
    if (newUserName.isEmpty && newEmail.isEmpty) return;

    setState(() { _profileSaving = true; _profileError = null; _profileSuccess = null; });
    try {
      final updated = await ApiClient.instance.updateProfile(
        userName: newUserName.isNotEmpty && newUserName != _profile?.userName
            ? newUserName
            : null,
        email: newEmail.isNotEmpty && newEmail != _profile?.email ? newEmail : null,
      );
      if (updated.userName != _profile?.userName) {
        await AuthService.instance.setUserName(updated.userName);
      }
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _profileSuccess = 'Profile updated.';
        _profileSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileError = e.toString().replaceFirst('Exception: ', '');
        _profileSaving = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPwCtrl.text;
    final newPw = _newPwCtrl.text;
    final confirm = _confirmPwCtrl.text;

    if (newPw != confirm) {
      setState(() { _pwError = 'New passwords do not match.'; });
      return;
    }
    if (newPw.length < 6) {
      setState(() { _pwError = 'Password must be at least 6 characters.'; });
      return;
    }

    setState(() { _pwSaving = true; _pwError = null; _pwSuccess = null; });
    try {
      await ApiClient.instance.changePassword(current, newPw);
      if (!mounted) return;
      setState(() {
        _pwSuccess = 'Password changed.';
        _pwSaving = false;
        _currentPwCtrl.clear();
        _newPwCtrl.clear();
        _confirmPwCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pwError = e.toString().replaceFirst('Exception: ', '');
        _pwSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Profile card ────────────────────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Profile',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    )),
                            const SizedBox(height: 4),
                            Text('Current: ${_profile?.userName} · ${_profile?.email}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey[600])),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _userNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            if (_profileError != null) ...[
                              const SizedBox(height: 8),
                              Text(_profileError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ],
                            if (_profileSuccess != null) ...[
                              const SizedBox(height: 8),
                              Text(_profileSuccess!,
                                  style: const TextStyle(color: Colors.green, fontSize: 12)),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _profileSaving ? null : _saveProfile,
                                child: _profileSaving
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Save changes'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Change password card ────────────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Change Password',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    )),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _currentPwCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Current password',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _newPwCtrl,
                              decoration: const InputDecoration(
                                labelText: 'New password',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmPwCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Confirm new password',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              obscureText: true,
                            ),
                            if (_pwError != null) ...[
                              const SizedBox(height: 8),
                              Text(_pwError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ],
                            if (_pwSuccess != null) ...[
                              const SizedBox(height: 8),
                              Text(_pwSuccess!,
                                  style: const TextStyle(color: Colors.green, fontSize: 12)),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _pwSaving ? null : _changePassword,
                                child: _pwSaving
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Change password'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
