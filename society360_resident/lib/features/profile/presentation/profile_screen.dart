import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../config/theme.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/auth/auth_controller.dart';
import '../../auth/presentation/phone_login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    final phoneNumber = storage.phoneNumber ?? 'Not available';
    final flatNumber = storage.flatNumber ?? 'N/A';
    final blockName = storage.blockName ?? 'N/A';
    final societyName = storage.societyName ?? 'Society360';
    final cityName = storage.cityName ?? 'Not set';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Profile Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryOrange.withOpacity(0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: AppTheme.primaryOrange.withOpacity(0.08),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ).animate().scale(duration: 600.ms),

                    const SizedBox(height: 20),

                    // Phone Number
                    Text(
                      phoneNumber,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 8),

                    // Address
                    Text(
                      '$flatNumber, Block $blockName',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Profile Information
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildInfoTile(
                            icon: Icons.apartment,
                            label: 'Society',
                            value: societyName,
                          ),
                          const Divider(color: AppTheme.surfaceBorder),
                          _buildInfoTile(
                            icon: Icons.location_city,
                            label: 'City',
                            value: cityName,
                          ),
                          const Divider(color: AppTheme.surfaceBorder),
                          _buildInfoTile(
                            icon: Icons.home,
                            label: 'Flat Number',
                            value: flatNumber,
                          ),
                          const Divider(color: AppTheme.surfaceBorder),
                          _buildInfoTile(
                            icon: Icons.domain,
                            label: 'Block',
                            value: blockName,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 24),

                    // Settings Section
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildSettingsTile(
                            icon: Icons.notifications,
                            label: 'Notifications',
                            onTap: () {
                              // TODO: Navigate to notifications settings
                            },
                          ),
                          const Divider(color: AppTheme.surfaceBorder),
                          _buildSettingsTile(
                            icon: Icons.security,
                            label: 'Privacy & Security',
                            onTap: () {
                              // TODO: Navigate to privacy settings
                            },
                          ),
                          const Divider(color: AppTheme.surfaceBorder),
                          _buildSettingsTile(
                            icon: Icons.help_outline,
                            label: 'Help & Support',
                            onTap: () {
                              // TODO: Navigate to help
                            },
                          ),
                          const Divider(color: AppTheme.surfaceBorder),
                          _buildSettingsTile(
                            icon: Icons.info_outline,
                            label: 'About',
                            onTap: () {
                              _showAboutDialog(context);
                            },
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 500.ms),

                    const SizedBox(height: 32),

                    // Logout Button
                    GradientButton(
                      text: 'Logout',
                      onPressed: () => _handleLogout(context, ref),
                      icon: Icons.logout,
                      width: double.infinity,
                    ).animate().fadeIn(delay: 600.ms),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: AppTheme.accentBlue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 24,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).signOut();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Society360'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Your Smart Society Companion',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Manage visitors, create guest passes, and stay connected with your society community.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
