import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/socket_service.dart';

/// Emergency List Screen
/// Shows all emergencies with Address and Resolve buttons
class EmergenciesScreen extends ConsumerStatefulWidget {
  const EmergenciesScreen({super.key});

  @override
  ConsumerState<EmergenciesScreen> createState() => _EmergenciesScreenState();
}

class _EmergenciesScreenState extends ConsumerState<EmergenciesScreen> {
  List<Map<String, dynamic>> _emergencies = [];
  bool _isLoading = true;
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _fetchEmergencies();

    // Add listeners for real-time updates
    _socketService.addEmergencyAlertListener(_handleEmergencyAlert);
    _socketService.addEmergencyUpdatedListener(_handleEmergencyUpdated);
  }

  @override
  void dispose() {
    _socketService.removeEmergencyAlertListener(_handleEmergencyAlert);
    _socketService.removeEmergencyUpdatedListener(_handleEmergencyUpdated);
    super.dispose();
  }

  void _handleEmergencyAlert(Map<String, dynamic> data) {
    debugPrint('🚨 Emergencies Screen: New emergency alert: $data');
    // Refresh the list to include the new emergency
    _fetchEmergencies();
  }

  void _handleEmergencyUpdated(Map<String, dynamic> data) {
    debugPrint('🔄 Emergencies Screen: Emergency updated: $data');
    if (mounted) {
      final emergencyId = data['emergency_id'];
      final status = data['status'];

      setState(() {
        final index = _emergencies.indexWhere((e) => e['id'] == emergencyId);
        if (index != -1) {
          _emergencies[index] = {..._emergencies[index], 'status': status};
          if (status == 'addressed' && data['addressed_at'] != null) {
            _emergencies[index]['addressed_at'] = data['addressed_at'];
          }
          if (status == 'resolved' && data['resolved_at'] != null) {
            _emergencies[index]['resolved_at'] = data['resolved_at'];
          }
        }
      });
    }
  }

  Future<void> _fetchEmergencies() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('📋 Emergencies: Fetching emergencies...');
      final apiClient = ref.read(apiClientProvider);

      final response = await apiClient.get('/emergencies', queryParameters: {
        'limit': 100,
      });

      debugPrint('📊 Emergencies: Response: ${response.data}');

      if (response.data['success'] == true) {
        final emergencies = response.data['data'] as List;

        // Sort by created_at (latest first)
        emergencies.sort((a, b) {
          final aTime = DateTime.parse(a['created_at']);
          final bTime = DateTime.parse(b['created_at']);
          return bTime.compareTo(aTime);
        });

        debugPrint('📊 Emergencies: Found ${emergencies.length} emergencies');

        setState(() {
          _emergencies = emergencies.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        throw Exception(response.data['error'] ?? 'Failed to fetch emergencies');
      }
    } catch (e) {
      debugPrint('❌ Emergencies: Error fetching emergencies: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch emergencies: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addressEmergency(String emergencyId) async {
    try {
      debugPrint('📍 Addressing emergency: $emergencyId');
      final apiClient = ref.read(apiClientProvider);

      final response = await apiClient.post('/emergencies/$emergencyId/address');

      if (response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency marked as addressed'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }

        // Refresh the list
        _fetchEmergencies();
      } else {
        throw Exception(response.data['error'] ?? 'Failed to address emergency');
      }
    } catch (e) {
      debugPrint('❌ Error addressing emergency: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to address emergency: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resolveEmergency(String emergencyId) async {
    try {
      debugPrint('✅ Resolving emergency: $emergencyId');
      final apiClient = ref.read(apiClientProvider);

      final response = await apiClient.post('/emergencies/$emergencyId/resolve');

      if (response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency marked as resolved'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }

        // Refresh the list
        _fetchEmergencies();
      } else {
        throw Exception(response.data['error'] ?? 'Failed to resolve emergency');
      }
    } catch (e) {
      debugPrint('❌ Error resolving emergency: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve emergency: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Emergencies',
          style: TextStyle(
            color: Color(0xFF1A1D1F),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1D1F)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEmergencies,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _emergencies.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchEmergencies,
                  child: _buildEmergenciesList(),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No emergencies',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All clear! No emergencies reported.',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergenciesList() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Emergencies list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: _emergencies.map((emergency) => _buildEmergencyCard(emergency)).toList(),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard(Map<String, dynamic> emergency) {
    final createdAt = DateTime.parse(emergency['created_at']);
    final timeStr = DateFormat('MMM dd, yyyy · hh:mm a').format(createdAt);
    final flatNumber = emergency['flat_number'] ?? 'N/A';
    final blockName = emergency['block_name'] ?? 'Unknown';
    final description = emergency['description'] ?? 'Emergency reported';
    final reportedByName = emergency['reported_by_name'] ?? 'Unknown';
    final reportedByPhone = emergency['reported_by_phone'] ?? '';
    final status = emergency['status'] ?? 'pending';

    Color statusColor;
    String statusText;
    IconData statusIcon;
    Color cardBorderColor;

    switch (status) {
      case 'pending':
        statusColor = const Color(0xFFEF4444);
        statusText = 'PENDING';
        statusIcon = Icons.warning;
        cardBorderColor = const Color(0xFFEF4444);
        break;
      case 'addressed':
        statusColor = const Color(0xFFF59E0B);
        statusText = 'ADDRESSED';
        statusIcon = Icons.check_circle_outline;
        cardBorderColor = const Color(0xFFF59E0B);
        break;
      case 'resolved':
        statusColor = AppTheme.successGreen;
        statusText = 'RESOLVED';
        statusIcon = Icons.check_circle;
        cardBorderColor = const Color(0xFFE8ECF4);
        break;
      default:
        statusColor = const Color(0xFF6F767E);
        statusText = 'UNKNOWN';
        statusIcon = Icons.help_outline;
        cardBorderColor = const Color(0xFFE8ECF4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 2),
        boxShadow: status == 'pending'
          ? [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon, Flat info, Status
            Row(
              children: [
                // Emergency Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.emergency,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Flat Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flat $flatNumber • Block $blockName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1D1F),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6F767E),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF6F767E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1D1F),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Reported By
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Color(0xFF6F767E)),
                const SizedBox(width: 6),
                Text(
                  'Reported by: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  reportedByName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D1F),
                  ),
                ),
                if (reportedByPhone.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    '· $reportedByPhone',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6F767E),
                    ),
                  ),
                ],
              ],
            ),

            // Action Buttons
            if (status == 'pending' || status == 'addressed') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (status == 'pending') {
                      _addressEmergency(emergency['id']);
                    } else if (status == 'addressed') {
                      _resolveEmergency(emergency['id']);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'pending'
                        ? const Color(0xFFF59E0B)
                        : AppTheme.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        status == 'pending'
                            ? Icons.check_circle_outline
                            : Icons.check_circle,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status == 'pending' ? 'Mark as Addressed' : 'Mark as Resolved',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
