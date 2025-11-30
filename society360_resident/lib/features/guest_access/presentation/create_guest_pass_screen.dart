import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/storage_service.dart';
import 'guest_pass_qr_screen.dart';

class CreateGuestPassScreen extends ConsumerStatefulWidget {
  const CreateGuestPassScreen({super.key});

  @override
  ConsumerState<CreateGuestPassScreen> createState() =>
      _CreateGuestPassScreenState();
}

class _CreateGuestPassScreenState
    extends ConsumerState<CreateGuestPassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _purposeController = TextEditingController();
  final _numberOfPeopleController = TextEditingController(text: '1');

  DateTime _validFrom = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _purposes = const [
    {'value': 'Guest Visit', 'icon': Icons.person},
    {'value': 'Delivery', 'icon': Icons.local_shipping},
    {'value': 'Service', 'icon': Icons.build},
    {'value': 'Family', 'icon': Icons.family_restroom},
    {'value': 'Other', 'icon': Icons.more_horiz},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _purposeController.dispose();
    _numberOfPeopleController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context, bool isFrom) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isFrom ? _validFrom : _validUntil,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isFrom ? _validFrom : _validUntil),
      );

      if (time != null) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        setState(() {
          if (isFrom) {
            _validFrom = dateTime;
            if (_validFrom.isAfter(_validUntil)) {
              _validUntil = _validFrom.add(const Duration(hours: 24));
            }
          } else {
            _validUntil = dateTime;
          }
        });
      }
    }
  }

  Future<void> _createGuestPass() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get flat_id from storage
      final storageService = ref.read(storageServiceProvider);
      final flatId = storageService.flatId;

      if (flatId == null) {
        throw Exception('Flat information not found. Please complete onboarding.');
      }

      // Verify user is authenticated
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate QR code
      final qrCode = const Uuid().v4();

      // Get API client (automatically handles auth via interceptor)
      final apiClient = ref.read(apiClientProvider);

      final requestData = {
        'visitor_name': _nameController.text,
        'phone': '+91${_phoneController.text}',
        'purpose': _purposeController.text,
        'flat_id': flatId,
        'expected_start': _validFrom.toIso8601String(),
        'expected_end': _validUntil.toIso8601String(),
        'qr_code': qrCode,
        'number_of_people': int.tryParse(_numberOfPeopleController.text) ?? 1,
      };

      debugPrint('📤 Creating guest pass: $requestData');

      // Call backend API (auth token automatically attached)
      final response = await apiClient.post(
        '/visitors/guest-pass',
        data: requestData,
      );

      debugPrint('✅ Guest pass created successfully: ${response.data}');

      // Extract access code from response
      final accessCode = response.data['data']?['visitor']?['access_code'] ?? '';
      debugPrint('🎫 Access code: $accessCode');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guest pass created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to QR screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GuestPassQrScreen(
              guestName: _nameController.text,
              guestPhone: '+91${_phoneController.text}',
              purpose: _purposeController.text,
              validFrom: _validFrom,
              validUntil: _validUntil,
              qrCode: qrCode,
              accessCode: accessCode,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error creating guest pass: $e');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create guest pass: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Guest Pass'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.accentCyan,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Create a guest pass with QR code for hassle-free entry',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Guest Name
              const Text(
                'Guest Name *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Enter guest name',
                  prefixIcon: Icon(Icons.person, color: AppTheme.accentBlue),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Guest name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Phone Number
              const Text(
                'Phone Number *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '10 digit mobile number',
                  prefixIcon: Icon(Icons.phone, color: AppTheme.accentBlue),
                  prefixText: '+91 ',
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Phone number is required';
                  }
                  if (value.length != 10) {
                    return 'Enter valid 10 digit number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Number of People
              const Text(
                'Number of People *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _numberOfPeopleController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: 'Approximate number of people',
                  prefixIcon: Icon(Icons.people, color: AppTheme.accentBlue),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Number of people is required';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number < 1) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Purpose
              const Text(
                'Purpose of Visit *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: null,
                decoration: const InputDecoration(
                  hintText: 'Select purpose',
                  prefixIcon: Icon(Icons.category, color: AppTheme.accentBlue),
                ),
                items: _purposes.map((purpose) {
                  return DropdownMenuItem(
                    value: purpose['value'] as String,
                    child: Row(
                      children: [
                        Icon(
                          purpose['icon'] as IconData,
                          size: 20,
                          color: AppTheme.accentBlue,
                        ),
                        const SizedBox(width: 12),
                        Text(purpose['value'] as String),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  _purposeController.text = value ?? '';
                },
                validator: (value) =>
                    value == null ? 'Please select purpose' : null,
              ),

              const SizedBox(height: 24),

              // Validity Period
              const Text(
                'Validity Period',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Valid From
              _buildDateTimeField(
                label: 'Valid From',
                dateTime: _validFrom,
                onTap: () => _selectDateTime(context, true),
              ),

              const SizedBox(height: 16),

              // Valid Until
              _buildDateTimeField(
                label: 'Valid Until',
                dateTime: _validUntil,
                onTap: () => _selectDateTime(context, false),
              ),

              const SizedBox(height: 40),

              // Create Button
              GradientButton(
                text: 'Generate QR Pass',
                onPressed: _isSubmitting ? null : _createGuestPass,
                isLoading: _isSubmitting,
                icon: Icons.qr_code,
                width: double.infinity,
                height: 56,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeField({
    required String label,
    required DateTime dateTime,
    required VoidCallback onTap,
  }) {
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today,
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
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.edit,
                size: 20,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
