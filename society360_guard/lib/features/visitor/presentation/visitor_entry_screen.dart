import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import 'visitor_form_controller.dart';
import 'widgets/step_visitor_details.dart';
import 'widgets/step_purpose.dart';
import 'widgets/step_destination.dart';
import 'widgets/step_submit.dart';

class VisitorEntryScreen extends ConsumerWidget {
  const VisitorEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(currentStepProvider);
    final formData = ref.watch(visitorFormControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Visitor Entry'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (currentStep > 0) {
              ref.read(currentStepProvider.notifier).previousStep();
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Progress Indicator
          _buildProgressIndicator(currentStep),

          // Step Content
          Expanded(
            child: _buildStepContent(currentStep),
          ),

          // Navigation Buttons
          _buildNavigationButtons(context, ref, currentStep, formData),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(int currentStep) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index == currentStep;
          final isCompleted = index < currentStep;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 4,
              decoration: BoxDecoration(
                color: isActive || isCompleted
                    ? AppTheme.primaryBlue
                    : AppTheme.textGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return const StepVisitorDetails();
      case 1:
        return const StepPurpose();
      case 2:
        return const StepDestination();
      case 3:
        return const StepSubmit();
      default:
        return const StepVisitorDetails();
    }
  }

  Widget _buildNavigationButtons(
    BuildContext context,
    WidgetRef ref,
    int currentStep,
    formData,
  ) {
    final canProceed = _canProceedToNextStep(currentStep, formData);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Back Button
            if (currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(currentStepProvider.notifier).previousStep();
                  },
                  child: const Text('Back'),
                ),
              ),
            if (currentStep > 0) const SizedBox(width: 16),

            // Next/Submit Button
            Expanded(
              flex: currentStep == 0 ? 1 : 1,
              child: ElevatedButton(
                onPressed: canProceed
                    ? () => _handleNextStep(context, ref, currentStep)
                    : null,
                child: Text(currentStep == 3 ? 'Submit' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canProceedToNextStep(int step, formData) {
    switch (step) {
      case 0:
        return formData.isStep1Valid;
      case 1:
        return formData.isStep2Valid;
      case 2:
        return formData.isStep3Valid;
      case 3:
        return formData.isFormComplete;
      default:
        return false;
    }
  }

  Future<void> _handleNextStep(
    BuildContext context,
    WidgetRef ref,
    int currentStep,
  ) async {
    if (currentStep == 3) {
      // Submit form
      final success = await ref
          .read(visitorFormControllerProvider.notifier)
          .submitForm();

      if (success && context.mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.check_circle,
              color: AppTheme.successGreen,
              size: 64,
            ),
            title: const Text('Success!'),
            content: const Text(
              'Visitor entry has been registered successfully.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(currentStepProvider.notifier).resetStep();
                  context.pop();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } else {
      // Proceed to next step
      ref.read(currentStepProvider.notifier).nextStep();
    }
  }
}
