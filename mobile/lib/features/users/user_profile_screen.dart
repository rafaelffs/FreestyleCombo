import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/models/user.dart';
import '../../theme/app_colors.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  PublicProfileDto? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ApiClient.instance.getPublicProfile(widget.userId);
      if (!mounted) return;
      setState(() { _profile = profile; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.indigo))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _ProfileHero(profile: _profile)),
                  ],
                ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final PublicProfileDto? profile;
  const _ProfileHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initial = (profile?.userName ?? '?').isNotEmpty
        ? profile!.userName.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.grad),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -50,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lime.withValues(alpha: 0.16)),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.of(context).pop()),
                    const SizedBox(height: 22),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Text(
                              initial,
                              style: GoogleFonts.plusJakartaSans(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            profile?.userName ?? '',
                            style: GoogleFonts.plusJakartaSans(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile?.email ?? '',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeroIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 18, color: Colors.white)),
      ),
    );
  }
}
