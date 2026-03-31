import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/auth_service.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for 2 seconds to show splash screen
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Check if user is already logged in
    final authService = context.read<AuthService>();
    await authService.checkLoginState();
    
    if (!mounted) return;
    
    // Navigate based on login state
    if (authService.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.train_rounded,
              size: 100,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Smart Rail Travel Assistant',
              style: theme.textTheme.displaySmall?.copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
