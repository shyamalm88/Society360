import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme.dart';
import '../visitor_form_controller.dart';

class StepPurpose extends ConsumerWidget {
  const StepPurpose({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formData = ref.watch(visitorFormControllerProvider);
    final selectedPurpose = formData.purpose;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Title
          Text(
            'Purpose of Visit',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Select the reason for this visit',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textGray,
                ),
          ),
          const SizedBox(height: 32),

          // Purpose Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildPurposeTile(
                context: context,
                ref: ref,
                purpose: 'Delivery',
                icon: Icons.local_shipping,
                color: AppTheme.primaryBlue,
                isSelected: selectedPurpose == 'Delivery',
              ),
              _buildPurposeTile(
                context: context,
                ref: ref,
                purpose: 'Guest',
                icon: Icons.person,
                color: AppTheme.successGreen,
                isSelected: selectedPurpose == 'Guest',
              ),
              _buildPurposeTile(
                context: context,
                ref: ref,
                purpose: 'Cab',
                icon: Icons.local_taxi,
                color: AppTheme.warningAmber,
                isSelected: selectedPurpose == 'Cab',
              ),
              _buildPurposeTile(
                context: context,
                ref: ref,
                purpose: 'Service',
                icon: Icons.build,
                color: const Color(0xFF8B5CF6), // Purple
                isSelected: selectedPurpose == 'Service',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeTile({
    required BuildContext context,
    required WidgetRef ref,
    required String purpose,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return Material(
      color: isSelected ? color.withOpacity(0.2) : AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          ref.read(visitorFormControllerProvider.notifier).updatePurpose(purpose);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 3,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                purpose,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isSelected ? color : AppTheme.textWhite,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 8),
                Icon(
                  Icons.check_circle,
                  color: color,
                  size: 24,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
