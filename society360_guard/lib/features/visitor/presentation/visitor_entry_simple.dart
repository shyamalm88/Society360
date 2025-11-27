import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../../data/repositories/society_repository.dart';
import '../../../data/models/visitor_form_data.dart';

class VisitorEntrySimpleScreen extends ConsumerStatefulWidget {
  const VisitorEntrySimpleScreen({super.key});

  @override
  ConsumerState<VisitorEntrySimpleScreen> createState() =>
      _VisitorEntrySimpleScreenState();
}

class _VisitorEntrySimpleScreenState
    extends ConsumerState<VisitorEntrySimpleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _vehicleController = TextEditingController();

  String? _selectedPurpose;
  String? _selectedBlockId;
  String? _selectedFlatId;
  String? _selectedFlatNumber;

  List<Block>? _blocks;
  List<Flat>? _flats;
  bool _isSubmitting = false;

  // Extended purpose list with icons
  final List<Map<String, dynamic>> _purposes = [
    {'value': 'Delivery', 'icon': Icons.local_shipping, 'color': Color(0xFFFF6B35)},
    {'value': 'Guest', 'icon': Icons.person, 'color': Color(0xFF4ECDC4)},
    {'value': 'Cab/Taxi', 'icon': Icons.local_taxi, 'color': Color(0xFFF7B801)},
    {'value': 'Service', 'icon': Icons.build, 'color': Color(0xFF95E1D3)},
    {'value': 'Food Delivery', 'icon': Icons.restaurant, 'color': Color(0xFFFF8B94)},
    {'value': 'Courier', 'icon': Icons.mail, 'color': Color(0xFF9B59B6)},
    {'value': 'Doctor', 'icon': Icons.medical_services, 'color': Color(0xFF3498DB)},
    {'value': 'Plumber', 'icon': Icons.plumbing, 'color': Color(0xFF2ECC71)},
    {'value': 'Electrician', 'icon': Icons.electrical_services, 'color': Color(0xFFE74C3C)},
    {'value': 'Carpenter', 'icon': Icons.carpenter, 'color': Color(0xFF8E44AD)},
    {'value': 'Cleaning', 'icon': Icons.cleaning_services, 'color': Color(0xFF1ABC9C)},
    {'value': 'Other', 'icon': Icons.more_horiz, 'color': Color(0xFF7F8C8D)},
  ];

  Map<String, dynamic>? _getPurposeByValue(String value) {
    return _purposes.firstWhere((p) => p['value'] == value);
  }

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  Future<void> _loadBlocks() async {
    final repo = ref.read(societyRepositoryProvider);
    final blocks = await repo.getBlocks();
    setState(() {
      _blocks = blocks;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Purpose validation is now handled by dropdown validator

    if (_selectedFlatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select block and flat')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create payload (removed invited_by - backend will use mock guard user)
      final payload = {
        'visitor_name': _nameController.text,
        'phone': '+91${_mobileController.text}',
        'vehicle_no': _vehicleController.text.isEmpty ? null : _vehicleController.text,
        'purpose': _selectedPurpose!.toLowerCase(),
        'flat_id': _selectedFlatId,
        'expected_start': DateTime.now().toIso8601String(),
        'expected_end': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
        'idempotency_key': 'guard_${DateTime.now().millisecondsSinceEpoch}',
      };

      print('=== Visitor Entry Submitted ===');
      print('Payload: $payload');
      print('==============================');

      // Actually submit to backend API!
      final repo = ref.read(societyRepositoryProvider);
      final success = await repo.submitVisitor(payload);

      setState(() {
        _isSubmitting = false;
      });

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit visitor entry')),
          );
        }
        return;
      }

      if (mounted) {
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
            content: Text(
              'Visitor ${_nameController.text} has been registered successfully.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.pop();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Visitor Entry'),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitForm,
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Submit Entry',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name Field (FIRST)
              Text(
                'Visitor Name *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Enter full name',
                  prefixIcon: Icon(Icons.person, color: AppTheme.primaryOrange),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Mobile Number
              Text(
                'Mobile Number *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                style: const TextStyle(fontSize: 18),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '10 digit mobile number',
                  prefixIcon: Icon(Icons.phone, color: AppTheme.primaryOrange),
                  counterText: '',
                  prefixText: '+91 ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Mobile number is required';
                  }
                  if (value.length != 10) {
                    return 'Enter valid 10 digit mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Vehicle Number (Optional)
              Text(
                'Vehicle Number (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _vehicleController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'e.g., KA01AB1234',
                  prefixIcon: Icon(Icons.directions_car, color: AppTheme.primaryOrange),
                ),
              ),
              const SizedBox(height: 24),

              // Purpose Dropdown
              Text(
                'Purpose of Visit *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPurpose,
                decoration: const InputDecoration(
                  hintText: 'Select purpose',
                  prefixIcon: Icon(Icons.info_outline, color: AppTheme.primaryOrange),
                ),
                items: _purposes.map<DropdownMenuItem<String>>((purpose) {
                  return DropdownMenuItem<String>(
                    value: purpose['value'] as String,
                    child: Row(
                      children: [
                        Icon(
                          purpose['icon'] as IconData,
                          size: 20,
                          color: purpose['color'] as Color,
                        ),
                        const SizedBox(width: 12),
                        Text(purpose['value'] as String),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPurpose = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select purpose of visit';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Block Selection
              Text(
                'Select Block *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              if (_blocks == null)
                const Center(child: CircularProgressIndicator())
              else
                _buildBlockSelector(_blocks!),
              const SizedBox(height: 24),

              // Flat Selection
              if (_flats != null) ...[
                Text(
                  'Select Flat *',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                _buildFlatGrid(_flats!),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockSelector(List<Block> blocks) {
    return SizedBox(
      height: 75,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: blocks.length,
        itemBuilder: (context, index) {
          final block = blocks[index];
          final isSelected = _selectedBlockId == block.id;

          return Container(
            width: 90,
            margin: const EdgeInsets.only(right: 12),
            child: Material(
              color: isSelected
                  ? AppTheme.primaryOrange.withOpacity(0.2)
                  : AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedBlockId = block.id;
                    _selectedFlatId = null;
                    _selectedFlatNumber = null;
                    _flats = block.flats;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        block.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              color: isSelected
                                  ? AppTheme.primaryOrange
                                  : AppTheme.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${block.flats.length} flats',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                            ),
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

  Widget _buildFlatGrid(List<Flat> flats) {
    // Group flats by floor
    final Map<int, List<Flat>> flatsByFloor = {};
    for (var flat in flats) {
      // Extract floor number from flat number (e.g., "A-101" -> floor 1)
      final flatNum = flat.number.split('-')[1];
      final floor = int.parse(flatNum[0]);
      if (!flatsByFloor.containsKey(floor)) {
        flatsByFloor[floor] = [];
      }
      flatsByFloor[floor]!.add(flat);
    }

    // Sort floors in ascending order
    final sortedFloors = flatsByFloor.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedFloors.map((floor) {
        final floorFlats = flatsByFloor[floor]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Floor header
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryOrange.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Floor $floor',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppTheme.textGray.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),

            // Flats grid for this floor
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemCount: floorFlats.length,
              itemBuilder: (context, index) {
                final flat = floorFlats[index];
                final isSelected = _selectedFlatId == flat.id;
                final isOccupied = flat.residentName != null;

                return Opacity(
                  opacity: isOccupied ? 1.0 : 0.4,
                  child: Material(
                    color: isSelected
                        ? AppTheme.primaryOrange.withOpacity(0.2)
                        : AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: isOccupied
                          ? () {
                              setState(() {
                                _selectedFlatId = flat.id;
                                _selectedFlatNumber = flat.number;
                              });
                            }
                          : null, // Disable tap for vacant flats
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              flat.number.split('-')[1], // Show only flat number
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 16,
                                    color:
                                        isSelected ? AppTheme.primaryOrange : AppTheme.textDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Icon(
                              Icons.home,
                              size: 14,
                              color: isOccupied
                                  ? AppTheme.successGreen
                                  : AppTheme.textGray.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }
}
