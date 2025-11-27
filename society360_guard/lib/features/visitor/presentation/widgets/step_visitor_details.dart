import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme.dart';
import '../visitor_form_controller.dart';

class StepVisitorDetails extends ConsumerStatefulWidget {
  const StepVisitorDetails({super.key});

  @override
  ConsumerState<StepVisitorDetails> createState() => _StepVisitorDetailsState();
}

class _StepVisitorDetailsState extends ConsumerState<StepVisitorDetails> {
  late final TextEditingController _mobileController;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final formData = ref.read(visitorFormControllerProvider);
    _mobileController = TextEditingController(text: formData.mobileNumber);
    _nameController = TextEditingController(text: formData.name);
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Title
          Text(
            'Visitor Details',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the visitor\'s basic information',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textGray,
                ),
          ),
          const SizedBox(height: 32),

          // Mobile Number Field
          Text(
            'Mobile Number',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            style: Theme.of(context).textTheme.bodyLarge,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              hintText: 'Enter 10 digit mobile number',
              prefixIcon: Icon(Icons.phone, color: AppTheme.primaryBlue),
              counterText: '',
            ),
            onChanged: (value) {
              ref.read(visitorFormControllerProvider.notifier).updateVisitorDetails(
                    mobileNumber: value,
                  );
            },
          ),
          const SizedBox(height: 24),

          // Name Field
          Text(
            'Visitor Name',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Enter visitor\'s full name',
              prefixIcon: Icon(Icons.person, color: AppTheme.primaryBlue),
            ),
            onChanged: (value) {
              ref.read(visitorFormControllerProvider.notifier).updateVisitorDetails(
                    name: value,
                  );
            },
          ),
          const SizedBox(height: 24),

          // Validation Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mobile number must be 10 digits and name must be at least 3 characters long',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textWhite,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
