import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/storage/storage_service.dart';
import 'intro_screen.dart';
import 'phone_login_screen.dart';
import '../../home/presentation/home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Show splash for minimum duration
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final storage = ref.read(storageServiceProvider);

    // Read the provider state first to trigger build() and initialize services
    ref.read(authControllerProvider);

    // Now get the notifier and check session
    final authController = ref.read(authControllerProvider.notifier);

    // Check session
    await authController.checkSession();

    if (!mounted) return;

    // Route based on state
    final authState = ref.read(authControllerProvider);

    Widget nextScreen;

    switch (authState) {
      case AuthState.complete:
        // User is authenticated and onboarded
        nextScreen = const HomeScreen();
        break;

      case AuthState.onboarding:
        // User is authenticated but needs onboarding
        nextScreen = const HomeScreen(); // Will show onboarding in home
        break;

      case AuthState.unauthenticated:
      case AuthState.initial:
      default:
        // Check if first launch
        if (storage.isFirstLaunch) {
          nextScreen = const IntroScreen();
        } else {
          nextScreen = const PhoneLoginScreen();
        }
        break;
    }

    // Navigate with replacement
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundLight,
              AppTheme.surfaceCard,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon with animation
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryOrange.withOpacity(0.2),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: AppTheme.primaryOrange.withOpacity(0.1),
                      blurRadius: 48,
                      offset: const Offset(0, 16),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.apartment,
                  size: 60,
                  color: Colors.white,
                ),
              ).animate().scale(
                    duration: 800.ms,
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: 40),

              // App Name
              const Text(
                'Society360',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 1.5,
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 600.ms),

              const SizedBox(height: 8),

              // Subtitle
              const Text(
                'Your Smart Society Companion',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ).animate().fadeIn(delay: 500.ms, duration: 600.ms),

              const SizedBox(height: 60),

              // Loading Indicator
              const CircularProgressIndicator(
                color: AppTheme.accentCyan,
                strokeWidth: 3,
              ).animate().fadeIn(delay: 700.ms),
            ],
          ),
        ),
      ),
    );
  }
}
