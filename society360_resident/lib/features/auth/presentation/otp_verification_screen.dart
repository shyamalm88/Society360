import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_controller.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../../home/presentation/home_screen.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends ConsumerState<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;
  int _resendCountdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();

    // Listen to auth state changes and navigate accordingly
    Future.microtask(() {
      ref.listenManual(authControllerProvider, (previous, next) {
        if (!mounted) return;

        print('🔔 [OTP LISTENER] Auth state changed from $previous to $next');

        // Only navigate if state changed to complete or onboarding
        if (next == AuthState.complete) {
          print('✅ [OTP LISTENER] Navigating to HomeScreen');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else if (next == AuthState.onboarding) {
          print('⚠️ [OTP LISTENER] Navigating to OnboardingScreen');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            (route) => false,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _getOtp() {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _verifyOtp() async {
    final otp = _getOtp();

    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter complete OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authController = ref.read(authControllerProvider.notifier);
      final success = await authController.verifyOtp(otp);

      print('🔍 [OTP] OTP verification result: $success');

      // The navigation will be handled by the listener in initState
      // No need to manually navigate here
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        // Clear OTP fields on error
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authController = ref.read(authControllerProvider.notifier);
      await authController.sendOtp(widget.phoneNumber);

      if (mounted) {
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentBlue.withOpacity(0.1),
                  border: Border.all(
                    color: AppTheme.accentBlue.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.message,
                  size: 50,
                  color: AppTheme.accentBlue,
                ),
              ).animate().scale(duration: 600.ms),

              const SizedBox(height: 40),

              // Title
              const Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 12),

              // Subtitle
              Text(
                'Enter the 6-digit code sent to\n${widget.phoneNumber}',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 60),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => _buildOtpField(index),
                ),
              ).animate().fadeIn(delay: 400.ms),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ).animate().shake(),
              ],

              const SizedBox(height: 40),

              // Verify Button
              GradientButton(
                text: 'Verify OTP',
                onPressed: _isLoading ? null : _verifyOtp,
                isLoading: _isLoading,
                icon: Icons.verified,
                width: double.infinity,
                height: 56,
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 32),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive OTP? ",
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (_resendCountdown > 0)
                    Text(
                      'Resend in ${_resendCountdown}s',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _resendOtp,
                      child: const Text(
                        'Resend OTP',
                        style: TextStyle(
                          color: AppTheme.accentBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField(int index) {
    return SizedBox(
      width: 50,
      child: TextFormField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppTheme.surfaceBorder,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppTheme.accentBlue,
              width: 2,
            ),
          ),
        ),
        onChanged: (value) {
          if (value.length == 1) {
            // Move to next field
            if (index < 5) {
              _otpFocusNodes[index + 1].requestFocus();
            } else {
              // Last field, verify OTP
              _otpFocusNodes[index].unfocus();
              _verifyOtp();
            }
          } else if (value.isEmpty && index > 0) {
            // Move to previous field on backspace
            _otpFocusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}
