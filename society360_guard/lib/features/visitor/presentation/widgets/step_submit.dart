import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme.dart';
import '../visitor_form_controller.dart';

class StepSubmit extends ConsumerWidget {
  const StepSubmit({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formData = ref.watch(visitorFormControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Title
          Text(
            'Review & Submit',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Please review the visitor details before submitting',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textGray,
                ),
          ),
          const SizedBox(height: 32),

          // Review Card
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Visitor Details Section
                _buildSection(
                  context: context,
                  title: 'Visitor Details',
                  icon: Icons.person,
                  children: [
                    _buildDetailRow(
                      context: context,
                      label: 'Name',
                      value: formData.name ?? '',
                    ),
                    _buildDetailRow(
                      context: context,
                      label: 'Mobile',
                      value: '+91 ${formData.mobileNumber ?? ''}',
                    ),
                  ],
                ),

                const Divider(height: 1),

                // Purpose Section
                _buildSection(
                  context: context,
                  title: 'Purpose',
                  icon: Icons.info,
                  children: [
                    _buildDetailRow(
                      context: context,
                      label: 'Visit Type',
                      value: formData.purpose ?? '',
                    ),
                  ],
                ),

                const Divider(height: 1),

                // Destination Section
                _buildSection(
                  context: context,
                  title: 'Destination',
                  icon: Icons.location_on,
                  children: [
                    _buildDetailRow(
                      context: context,
                      label: 'Flat Number',
                      value: formData.flatNumber ?? '',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Info Note
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
                    'A notification will be sent to the resident for approval',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryBlue,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textGray,
                ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
