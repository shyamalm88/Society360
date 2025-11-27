import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/metadata_models.dart';
import '../../core/api/api_client.dart';

/// Metadata Repository
/// Fetches data from backend API for cascading dropdowns
class MetadataRepository {
  final ApiClient _apiClient;

  MetadataRepository(this._apiClient);

  /// Fetch all cities
  Future<List<City>> getCities() async {
    try {
      final response = await _apiClient.get('/cities');

      if (response.data['success'] == true) {
        final List<String> cityNames = List<String>.from(response.data['data']);

        // Convert city names to City objects
        // Note: Backend returns just city names, we create IDs from names
        return cityNames.map((cityName) {
          return City(
            id: cityName.toLowerCase().replaceAll(' ', '_'),
            name: cityName,
            state: '', // Backend doesn't return state info yet
          );
        }).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching cities: $e');
      return [];
    }
  }

  /// Fetch societies for a city
  Future<List<Society>> getSocietiesByCity(String cityId) async {
    try {
      // Convert cityId back to city name (we created IDs from names in getCities)
      final cityName = cityId.replaceAll('_', ' ').split(' ').map((word) =>
        word[0].toUpperCase() + word.substring(1)).join(' ');

      final response = await _apiClient.get('/societies', queryParameters: {
        'city': cityName,
      });

      if (response.data['success'] == true) {
        final List<dynamic> societiesData = response.data['data'];

        return societiesData.map((societyData) {
          return Society(
            id: societyData['id'],
            name: societyData['name'],
            address: societyData['address'] ?? '',
            cityId: cityId, // Use the passed cityId
            totalBlocks: 0, // Backend doesn't return this info yet
            totalFlats: 0, // Backend doesn't return this info yet
          );
        }).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching societies: $e');
      return [];
    }
  }

  /// Fetch blocks for a society
  Future<List<Block>> getBlocksBySociety(String societyId) async {
    try {
      // Step 1: Get complexes for the society
      final complexesResponse = await _apiClient.get('/complexes', queryParameters: {
        'society_id': societyId,
      });

      if (complexesResponse.data['success'] != true) {
        return [];
      }

      final List<dynamic> complexesData = complexesResponse.data['data'];
      final List<Block> allBlocks = [];

      // Step 2: For each complex, get its blocks
      for (final complexData in complexesData) {
        final complexId = complexData['id'];

        final blocksResponse = await _apiClient.get('/blocks', queryParameters: {
          'complex_id': complexId,
        });

        if (blocksResponse.data['success'] == true) {
          final List<dynamic> blocksData = blocksResponse.data['data'];

          for (final blockData in blocksData) {
            allBlocks.add(Block(
              id: blockData['id'],
              name: blockData['name'],
              societyId: societyId,
              totalFlats: 0, // Will be calculated from flats
              floors: 0, // Backend doesn't return this info yet
            ));
          }
        }
      }

      return allBlocks;
    } catch (e) {
      print('Error fetching blocks: $e');
      return [];
    }
  }

  /// Fetch flats for a block
  Future<List<Flat>> getFlatsByBlock(String blockId) async {
    try {
      final response = await _apiClient.get('/flats', queryParameters: {
        'block_id': blockId,
      });

      if (response.data['success'] == true) {
        final List<dynamic> flatsData = response.data['data'];

        return flatsData.map((flatData) {
          // Extract floor number from flat_number (e.g., "A-301" -> floor 3)
          final flatNumber = flatData['flat_number'] as String;
          final parts = flatNumber.split('-');
          int floor = 0;
          if (parts.length > 1) {
            final numberPart = parts[1];
            if (numberPart.isNotEmpty) {
              floor = int.tryParse(numberPart[0]) ?? 0;
            }
          }

          // Convert BHK to type string (e.g., 2 -> "2BHK")
          final bhk = flatData['bhk'];
          final type = bhk != null ? '${bhk}BHK' : 'Unknown';

          return Flat(
            id: flatData['id'],
            number: flatNumber,
            blockId: blockId,
            floor: floor,
            type: type,
            isOccupied: false, // Backend doesn't return occupancy status yet
            ownerName: null,
          );
        }).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching flats: $e');
      return [];
    }
  }

  /// Validate flat availability
  Future<bool> validateFlat(String flatId) async {
    // TODO: Implement flat validation with backend
    return true;
  }

  /// Get full metadata for a flat (for displaying in profile)
  Future<Map<String, String>> getFlatMetadata(String flatId) async {
    // TODO: Implement flat metadata fetching from backend
    return {
      'flatNumber': 'Unknown',
      'blockName': 'Unknown',
      'societyName': 'Unknown',
      'cityName': 'Unknown',
    };
  }

  /// Submit resident request to backend
  Future<bool> submitResidentRequest({
    required String flatId,
    required String requestedRole, // 'owner', 'tenant', or 'other'
    String? note,
  }) async {
    try {
      final response = await _apiClient.post('/resident-requests', data: {
        'flat_id': flatId,
        'requested_role': requestedRole,
        'note': note,
      });

      if (response.data['success'] == true) {
        print('✅ Resident request submitted successfully');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error submitting resident request: $e');
      return false;
    }
  }

  /// Get current user's flat assignments
  Future<List<Map<String, dynamic>>> getMyFlats() async {
    try {
      print('🔍 [METADATA] Calling /my-flats endpoint...');
      final response = await _apiClient.get('/my-flats');

      print('🔍 [METADATA] Response received: ${response.data}');

      if (response.data['success'] == true) {
        final List<dynamic> flatsData = response.data['data'];
        print('✅ [METADATA] Fetched ${flatsData.length} flat(s) for current user');
        print('🔍 [METADATA] Flat data: $flatsData');
        return List<Map<String, dynamic>>.from(flatsData);
      } else {
        print('⚠️ [METADATA] API returned success=false: ${response.data}');
        return [];
      }
    } catch (e, stackTrace) {
      print('❌ [METADATA] Error fetching user flats: $e');
      print('❌ [METADATA] Stack trace: $stackTrace');
      return [];
    }
  }
}

/// Riverpod Provider for Metadata Repository
final metadataRepositoryProvider = Provider<MetadataRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MetadataRepository(apiClient);
});

/// Provider for cities list
final citiesProvider = FutureProvider<List<City>>((ref) async {
  final repo = ref.watch(metadataRepositoryProvider);
  return repo.getCities();
});

/// Provider for societies by city
final societiesByCityProvider =
    FutureProvider.family<List<Society>, String>((ref, cityId) async {
  final repo = ref.watch(metadataRepositoryProvider);
  return repo.getSocietiesByCity(cityId);
});

/// Provider for blocks by society
final blocksBySocietyProvider =
    FutureProvider.family<List<Block>, String>((ref, societyId) async {
  final repo = ref.watch(metadataRepositoryProvider);
  return repo.getBlocksBySociety(societyId);
});

/// Provider for flats by block
final flatsByBlockProvider =
    FutureProvider.family<List<Flat>, String>((ref, blockId) async {
  final repo = ref.watch(metadataRepositoryProvider);
  return repo.getFlatsByBlock(blockId);
});
