import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/auth_service.dart';
import '../../data/theme_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthService>().currentUser;
    final themeService = context.watch<ThemeService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(Icons.person, size: 64, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user ?? 'Guest User',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 48),
          _buildProfileTile(context, Icons.bookmark, 'Saved Trips', () {
            Navigator.pushNamed(context, '/history');
          }),
          _buildProfileTile(
            context,
            Icons.dark_mode,
            'Dark Mode',
            () => themeService.toggleTheme(),
            trailing: Switch(
              value: themeService.isDarkMode,
              onChanged: (_) => themeService.toggleTheme(),
            ),
          ),
          _buildProfileTile(context, Icons.notifications, 'Notifications', () {}, trailing: Switch(value: true, onChanged: (v) {})),
          _buildProfileTile(context, Icons.language, 'Language', () {}, subtitle: 'English'),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () async {
              await context.read<AuthService>().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    Widget? trailing,
    String? subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
