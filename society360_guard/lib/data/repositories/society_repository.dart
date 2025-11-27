import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/visitor_form_data.dart';
import '../../core/api/api_client.dart';

part 'society_repository.g.dart';

/// Society Repository
/// Fetches society structure (Blocks and Flats) from backend API
class SocietyRepository {
  final ApiClient _apiClient;

  SocietyRepository(this._apiClient);

  /// Get all blocks with their flats from the backend
  Future<List<Block>> getBlocks() async {
    try {
      // For now, we'll fetch from a specific society
      // TODO: Make society_id dynamic based on logged-in guard
      const societyId = 'e74be90b-907b-4b86-91b9-f8ef3fc80320'; // From seed data

      // Step 1: Get all complexes for this society
      final complexesResponse = await _apiClient.get(
        '/complexes',
        queryParameters: {'society_id': societyId},
      );

      if (complexesResponse.data['success'] != true) {
        throw Exception('Failed to fetch complexes');
      }

      final complexes = complexesResponse.data['data'] as List;
      if (complexes.isEmpty) {
        return [];
      }

      // For simplicity, use the first complex
      final complexId = complexes[0]['id'];

      // Step 2: Get all blocks for this complex
      final blocksResponse = await _apiClient.get(
        '/blocks',
        queryParameters: {'complex_id': complexId},
      );

      if (blocksResponse.data['success'] != true) {
        throw Exception('Failed to fetch blocks');
      }

      final blocksData = blocksResponse.data['data'] as List;
      final blocks = <Block>[];

      // Step 3: For each block, fetch its flats
      for (final blockData in blocksData) {
        final blockId = blockData['id'];
        final blockName = blockData['name'];

        // Fetch flats for this block
        final flatsResponse = await _apiClient.get(
          '/flats',
          queryParameters: {'block_id': blockId},
        );

        if (flatsResponse.data['success'] != true) {
          continue; // Skip this block if flats fetch fails
        }

        final flatsData = flatsResponse.data['data'] as List;
        final flats = flatsData.map((flatData) {
          return Flat(
            id: flatData['id'],
            number: flatData['flat_number'],
            residentName: flatData['resident_name'], // From flat_occupancies join
          );
        }).toList();

        blocks.add(Block(
          id: blockId,
          name: blockName,
          flats: flats,
        ));
      }

      return blocks;
    } catch (e) {
      print('Error fetching blocks: $e');
      throw Exception('Failed to load blocks and flats: $e');
    }
  }

  /// Submit visitor entry to backend
  Future<bool> submitVisitor(Map<String, dynamic> visitorData) async {
    try {
      print('🚀 [submitVisitor] Starting API call to /visitors');
      print('📦 [submitVisitor] Payload: $visitorData');

      final response = await _apiClient.post('/visitors', data: visitorData);

      print('📡 [submitVisitor] Response received: ${response.statusCode}');
      print('📦 [submitVisitor] Response data: ${response.data}');

      if (response.data['success'] == true) {
        print('✅ Visitor created successfully');
        print('Visitor ID: ${response.data['data']['id']}');
        return true;
      } else {
        print('❌ Failed to create visitor: ${response.data['error']}');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Error submitting visitor: $e');
      print('📍 Stack trace: $stackTrace');
      return false;
    }
  }
}

/// Riverpod provider for SocietyRepository
@riverpod
SocietyRepository societyRepository(SocietyRepositoryRef ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SocietyRepository(apiClient);
}

/// Provider to fetch all blocks
@riverpod
Future<List<Block>> blocks(BlocksRef ref) {
  final repo = ref.watch(societyRepositoryProvider);
  return repo.getBlocks();
}
