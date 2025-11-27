import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../config/theme.dart';
import '../../../core/storage/storage_service.dart';
import 'phone_login_screen.dart';

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<IntroSlide> _slides = const [
    IntroSlide(
      icon: Icons.security,
      title: 'Enhanced Security',
      description:
          'Advanced visitor management with real-time notifications and approval system for your safety',
      gradient: LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    IntroSlide(
      icon: Icons.touch_app,
      title: 'Ultimate Convenience',
      description:
          'Pre-approve visitors, generate QR codes, and manage guests with just a few taps',
      gradient: LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    IntroSlide(
      icon: Icons.people,
      title: 'Connected Community',
      description:
          'Stay connected with your society, receive updates, and manage everything in one place',
      gradient: LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _onGetStarted() async {
    // Mark first launch as complete
    await ref.read(storageServiceProvider).setFirstLaunchComplete();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
      );
    }
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _onGetStarted();
    }
  }

  void _onSkip() {
    _onGetStarted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _onSkip,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return _buildSlide(_slides[index], index);
                },
              ),
            ),

            // Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => _buildDot(index),
              ),
            ),

            const SizedBox(height: 40),

            // Next/Get Started Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GradientButton(
                text: _currentPage == _slides.length - 1
                    ? 'Get Started'
                    : 'Next',
                onPressed: _onNext,
                icon: _currentPage == _slides.length - 1
                    ? Icons.arrow_forward
                    : null,
                width: double.infinity,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(IntroSlide slide, int index) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with gradient background
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: slide.gradient,
              boxShadow: [
                BoxShadow(
                  color: slide.gradient.colors.first.withOpacity(0.2),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: slide.gradient.colors.first.withOpacity(0.1),
                  blurRadius: 48,
                  offset: const Offset(0, 16),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              slide.icon,
              size: 80,
              color: Colors.white,
            ),
          )
              .animate(key: ValueKey('icon_$index'))
              .scale(duration: 600.ms, curve: Curves.easeOut),

          const SizedBox(height: 60),

          // Title
          Text(
            slide.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ).animate(key: ValueKey('title_$index')).fadeIn(delay: 200.ms, duration: 500.ms),

          const SizedBox(height: 20),

          // Description
          Text(
            slide.description,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate(key: ValueKey('description_$index')).fadeIn(delay: 400.ms, duration: 500.ms),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.accentBlue : AppTheme.textMuted,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class IntroSlide {
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;

  const IntroSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}
