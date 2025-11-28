import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final List<String> _enteredPin = [];
  bool _isShaking = false;
  bool _isLoading = false;

  static const int pinLength = 6;

  void _onNumberPressed(String number) {
    if (_enteredPin.length < pinLength && !_isLoading) {
      setState(() {
        _enteredPin.add(number);
      });

      // Auto-submit when PIN is complete
      if (_enteredPin.length == pinLength) {
        _submitPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty && !_isLoading) {
      setState(() {
        _enteredPin.removeLast();
      });
    }
  }

  Future<void> _submitPin() async {
    final pin = _enteredPin.join();

    setState(() {
      _isLoading = true;
    });

    // Attempt login
    final success = await ref.read(authProvider.notifier).loginWithPin(pin);

    if (mounted) {
      if (success) {
        // Navigate to dashboard (handled by go_router redirect)
        context.go('/dashboard');
      } else {
        // Show shake animation and clear PIN
        setState(() {
          _isShaking = true;
          _isLoading = false;
        });

        // Reset shake animation after delay
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          setState(() {
            _enteredPin.clear();
            _isShaking = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section with Gradient
              Expanded(
                flex: 2,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo/Icon with Gradient & Shadow
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.elevatedShadow,
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title with improved typography
                      Text(
                        'Society360',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrangeLight.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryOrangeLight.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Guard Access Portal',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.textGray,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // PIN Dots Section
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text(
                      'Enter Your PIN',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.textGray,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 24),

                    // PIN Dots with shake animation
                    _buildPinDots().animate(target: _isShaking ? 1 : 0).shake(
                          duration: 500.ms,
                          hz: 5,
                          curve: Curves.easeInOut,
                        ),
                  ],
                ),
              ),

              // Keypad Section
              Expanded(
                flex: 3,
                child: _buildNumericKeypad(),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pinLength,
        (index) {
          final isFilled = index < _enteredPin.length;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isFilled ? AppTheme.primaryGradient : null,
              color: isFilled ? null : Colors.transparent,
              border: Border.all(
                color: isFilled ? Colors.transparent : AppTheme.textLight,
                width: 2.5,
              ),
              boxShadow: isFilled
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNumericKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Row 1: 1, 2, 3
          _buildKeypadRow(['1', '2', '3']),

          // Row 2: 4, 5, 6
          _buildKeypadRow(['4', '5', '6']),

          // Row 3: 7, 8, 9
          _buildKeypadRow(['7', '8', '9']),

          // Row 4: empty, 0, backspace
          _buildKeypadRow(['', '0', 'backspace']),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) {
        if (number.isEmpty) {
          return const Expanded(child: SizedBox());
        }

        if (number == 'backspace') {
          return Expanded(
            child: _buildKeypadButton(
              child: const Icon(
                Icons.backspace_rounded,
                size: 28,
                color: AppTheme.textDark,
              ),
              onPressed: _onBackspace,
            ),
          );
        }

        return Expanded(
          child: _buildKeypadButton(
            child: Text(
              number,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            onPressed: () => _onNumberPressed(number),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton({
    required Widget child,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: _isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(20),
          splashColor: AppTheme.primaryOrangeLight.withOpacity(0.2),
          highlightColor: AppTheme.primaryOrangeLight.withOpacity(0.1),
          child: Container(
            height: 72,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
