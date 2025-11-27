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
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo/Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.security,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Society360',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Guard Access',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textGray,
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
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? AppTheme.primaryOrange : Colors.transparent,
              border: Border.all(
                color: isFilled ? AppTheme.primaryOrange : AppTheme.textGray,
                width: 2,
              ),
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
                Icons.backspace_outlined,
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
              style: Theme.of(context).textTheme.headlineMedium,
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
      child: Material(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 70,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
