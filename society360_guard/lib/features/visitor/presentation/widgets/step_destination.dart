import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme.dart';
import '../../../../data/repositories/society_repository.dart';
import '../../../../data/models/visitor_form_data.dart';
import '../visitor_form_controller.dart';

class StepDestination extends ConsumerStatefulWidget {
  const StepDestination({super.key});

  @override
  ConsumerState<StepDestination> createState() => _StepDestinationState();
}

class _StepDestinationState extends ConsumerState<StepDestination> {
  String? selectedBlockId;
  List<Flat>? selectedBlockFlats;

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(blocksProvider);
    final formData = ref.watch(visitorFormControllerProvider);

    return blocksAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text('Error loading blocks: $error'),
          ],
        ),
      ),
      data: (blocks) {
        // Initialize selectedBlockId if formData has it
        if (selectedBlockId == null && formData.blockId != null) {
          selectedBlockId = formData.blockId;
          final block = blocks.firstWhere((b) => b.id == selectedBlockId);
          selectedBlockFlats = block.flats;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Title
              Text(
                'Destination',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Select the block and flat number',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textGray,
                    ),
              ),
              const SizedBox(height: 32),

              // Block Selection
              Text(
                'Select Block',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _buildBlockSelector(blocks),
              const SizedBox(height: 32),

              // Flat Selection (only if block is selected)
              if (selectedBlockFlats != null) ...[
                Text(
                  'Select Flat',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _buildFlatGrid(selectedBlockFlats!, formData.flatId),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlockSelector(List<Block> blocks) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: blocks.length,
        itemBuilder: (context, index) {
          final block = blocks[index];
          final isSelected = selectedBlockId == block.id;

          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 16),
            child: Material(
              color: isSelected
                  ? AppTheme.primaryBlue.withOpacity(0.2)
                  : AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () {
                  setState(() {
                    selectedBlockId = block.id;
                    selectedBlockFlats = block.flats;
                  });

                  ref
                      .read(visitorFormControllerProvider.notifier)
                      .updateDestination(
                        blockId: block.id,
                        flatId: null, // Reset flat selection
                        flatNumber: null,
                      );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        block.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : AppTheme.textWhite,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${block.flats.length} flats',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlatGrid(List<Flat> flats, String? selectedFlatId) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: flats.length,
      itemBuilder: (context, index) {
        final flat = flats[index];
        final isSelected = selectedFlatId == flat.id;

        return Material(
          color: isSelected
              ? AppTheme.primaryBlue.withOpacity(0.2)
              : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              debugPrint('🔵 Flat tapped: ${flat.number} (ID: ${flat.id})');
              ref.read(visitorFormControllerProvider.notifier).updateDestination(
                    flatId: flat.id,
                    flatNumber: flat.number,
                  );
            },
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    flat.number.split('-')[1], // Show only flat number
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color:
                              isSelected ? AppTheme.primaryBlue : AppTheme.textWhite,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (flat.residentName != null) ...[
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.home,
                      size: 16,
                      color: AppTheme.successGreen,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
