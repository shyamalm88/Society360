import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../config/theme.dart';
import '../../../data/models/metadata_models.dart';
import '../../../data/repositories/metadata_repository.dart';
import '../../../core/auth/auth_controller.dart';
import '../../home/presentation/home_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Selected values
  City? _selectedCity;
  Society? _selectedSociety;
  Block? _selectedBlock;
  Flat? _selectedFlat;

  // Loading states
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(citiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                      ),
                      child: const Icon(
                        Icons.location_city,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tell us where you live',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select your location details to complete your profile',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms),

              const SizedBox(height: 32),

              // City Selection
              citiesAsync.when(
                data: (cities) => _buildCityDropdown(cities),
                loading: () => _buildLoadingDropdown('Loading cities...'),
                error: (error, stack) => _buildErrorCard('Failed to load cities'),
              ),

              const SizedBox(height: 20),

              // Society Selection
              if (_selectedCity != null) ...[
                _buildSocietyDropdown(),
                const SizedBox(height: 20),
              ],

              // Block Selection
              if (_selectedSociety != null) ...[
                _buildBlockDropdown(),
                const SizedBox(height: 20),
              ],

              // Flat Selection
              if (_selectedBlock != null) ...[
                _buildFlatDropdown(),
                const SizedBox(height: 32),
              ],

              // Submit Button
              if (_selectedFlat != null)
                GradientButton(
                  text: 'Continue to Home',
                  onPressed: _isSubmitting ? null : _submitOnboarding,
                  isLoading: _isSubmitting,
                  icon: Icons.arrow_forward,
                  width: double.infinity,
                  height: 56,
                ).animate().fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCityDropdown(List<City> cities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select City',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<City>(
          value: _selectedCity,
          decoration: InputDecoration(
            hintText: 'Choose your city',
            prefixIcon: const Icon(Icons.location_city, color: AppTheme.accentBlue),
          ),
          items: cities.map((city) {
            return DropdownMenuItem(
              value: city,
              child: Text('${city.name}, ${city.state}'),
            );
          }).toList(),
          onChanged: (city) {
            setState(() {
              _selectedCity = city;
              _selectedSociety = null;
              _selectedBlock = null;
              _selectedFlat = null;
            });
          },
          validator: (value) => value == null ? 'Please select a city' : null,
        ),
      ],
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildSocietyDropdown() {
    final societiesAsync = ref.watch(
      societiesByCityProvider(_selectedCity!.id),
    );

    return societiesAsync.when(
      data: (societies) {
        if (societies.isEmpty) {
          return _buildErrorCard('No societies found in this city');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Society',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Society>(
              value: _selectedSociety,
              decoration: InputDecoration(
                hintText: 'Choose your society',
                prefixIcon: const Icon(Icons.apartment, color: AppTheme.accentBlue),
              ),
              items: societies.map((society) {
                return DropdownMenuItem(
                  value: society,
                  child: Text(
                    society.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (society) {
                setState(() {
                  _selectedSociety = society;
                  _selectedBlock = null;
                  _selectedFlat = null;
                });
              },
              validator: (value) =>
                  value == null ? 'Please select a society' : null,
            ),
          ],
        ).animate().fadeIn(duration: 600.ms);
      },
      loading: () => _buildLoadingDropdown('Loading societies...'),
      error: (error, stack) => _buildErrorCard('Failed to load societies'),
    );
  }

  Widget _buildBlockDropdown() {
    final blocksAsync = ref.watch(
      blocksBySocietyProvider(_selectedSociety!.id),
    );

    return blocksAsync.when(
      data: (blocks) {
        if (blocks.isEmpty) {
          return _buildErrorCard('No blocks found in this society');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Block',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Block>(
              value: _selectedBlock,
              decoration: InputDecoration(
                hintText: 'Choose your block',
                prefixIcon: const Icon(Icons.domain, color: AppTheme.accentBlue),
              ),
              items: blocks.map((block) {
                return DropdownMenuItem(
                  value: block,
                  child: Text(block.name),
                );
              }).toList(),
              onChanged: (block) {
                setState(() {
                  _selectedBlock = block;
                  _selectedFlat = null;
                });
              },
              validator: (value) => value == null ? 'Please select a block' : null,
            ),
          ],
        ).animate().fadeIn(duration: 600.ms);
      },
      loading: () => _buildLoadingDropdown('Loading blocks...'),
      error: (error, stack) => _buildErrorCard('Failed to load blocks'),
    );
  }

  Widget _buildFlatDropdown() {
    final flatsAsync = ref.watch(
      flatsByBlockProvider(_selectedBlock!.id),
    );

    return flatsAsync.when(
      data: (flats) {
        if (flats.isEmpty) {
          return _buildErrorCard('No flats found in this block');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Flat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Flat>(
              value: _selectedFlat,
              decoration: InputDecoration(
                hintText: 'Choose your flat',
                prefixIcon: const Icon(Icons.home, color: AppTheme.accentBlue),
              ),
              items: flats.map((flat) {
                return DropdownMenuItem(
                  value: flat,
                  child: Text('${flat.number} (${flat.type})'),
                );
              }).toList(),
              onChanged: (flat) {
                setState(() {
                  _selectedFlat = flat;
                });
              },
              validator: (value) => value == null ? 'Please select a flat' : null,
            ),
          ],
        ).animate().fadeIn(duration: 600.ms);
      },
      loading: () => _buildLoadingDropdown('Loading flats...'),
      error: (error, stack) => _buildErrorCard('Failed to load flats'),
    );
  }

  Widget _buildLoadingDropdown(String message) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accentBlue,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            message,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorRed),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedFlat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select all required fields'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authController = ref.read(authControllerProvider.notifier);

      await authController.completeOnboarding(
        flatId: _selectedFlat!.id,
        flatNumber: _selectedFlat!.number,
        blockName: _selectedBlock!.name,
        societyName: _selectedSociety!.name,
        cityName: _selectedCity!.name,
      );

      if (mounted) {
        // Navigate to home
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
