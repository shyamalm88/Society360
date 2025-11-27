import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_controller.dart';
import 'otp_verification_screen.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phoneNumber = '+91${_phoneController.text}';
      final authController = ref.read(authControllerProvider.notifier);

      final success = await authController.sendOtp(phoneNumber);

      if (mounted && success) {
        // Navigate to OTP verification screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: phoneNumber,
            ),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // App Icon
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
                    Icons.apartment,
                    size: 50,
                    color: Colors.white,
                  ),
                ).animate().scale(duration: 600.ms),

                const SizedBox(height: 40),

                // Title
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 12),

                // Subtitle
                const Text(
                  'Enter your phone number to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 60),

                // Phone Number Input
                Text(
                  'Phone Number',
                  style: Theme.of(context).textTheme.titleMedium,
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: const TextStyle(
                    fontSize: 18,
                    letterSpacing: 1.5,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Enter 10 digit mobile number',
                    prefixIcon: const Icon(
                      Icons.phone_android,
                      color: AppTheme.accentBlue,
                    ),
                    prefixText: '+91  ',
                    prefixStyle: const TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    counterText: '',
                    errorText: _errorMessage,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone number is required';
                    }
                    if (value.length != 10) {
                      return 'Enter a valid 10 digit number';
                    }
                    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value)) {
                      return 'Enter a valid Indian mobile number';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 40),

                // Send OTP Button
                GradientButton(
                  text: 'Send OTP',
                  onPressed: _isLoading ? null : _sendOtp,
                  isLoading: _isLoading,
                  icon: Icons.send,
                  width: double.infinity,
                  height: 56,
                ).animate().fadeIn(delay: 600.ms),

                const SizedBox(height: 32),

                // Info Text
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.accentCyan,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We will send you a one-time password (OTP) to verify your phone number',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 700.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
