import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/api/api_client.dart';

class MyVisitorsScreen extends ConsumerStatefulWidget {
  const MyVisitorsScreen({super.key});

  @override
  ConsumerState<MyVisitorsScreen> createState() => _MyVisitorsScreenState();
}

class _MyVisitorsScreenState extends ConsumerState<MyVisitorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _allVisitors = [];
  bool _isLoading = true;
  int _activeDisplayCount = 10;
  int _historyDisplayCount = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllVisitors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllVisitors() async {
    setState(() => _isLoading = true);

    try {
      final storage = ref.read(storageServiceProvider);
      final flatId = storage.flatId ?? '';

      if (flatId.isEmpty) {
        debugPrint('❌ No flat ID found');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('📋 My Visitors: Fetching visitors for flat: $flatId');
      final apiClient = ref.read(apiClientProvider);

      final response = await apiClient.get('/visitors', queryParameters: {
        'flat_id': flatId,
      });

      if (response.data['success'] == true) {
        final List<dynamic> visitorsData = response.data['data'];
        final allVisitors = visitorsData.cast<Map<String, dynamic>>();

        // Sort by expected time (latest first)
        allVisitors.sort((a, b) {
          final aTime = DateTime.parse(a['expected_start'] ?? a['created_at']);
          final bTime = DateTime.parse(b['expected_start'] ?? b['created_at']);
          return bTime.compareTo(aTime);
        });

        debugPrint('📊 My Visitors: Found ${allVisitors.length} visitors');

        setState(() {
          _allVisitors = allVisitors;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ My Visitors: Error fetching visitors: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch visitors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get icon and color based on visitor purpose (matches guard app exactly)
  Map<String, dynamic> _getPurposeIconAndColor(String purpose) {
    final purposeLower = purpose.toLowerCase();

    if (purposeLower.contains('delivery') && !purposeLower.contains('food')) {
      return {'icon': Icons.local_shipping, 'color': const Color(0xFFFF6B35)};
    } else if (purposeLower.contains('guest')) {
      return {'icon': Icons.person, 'color': const Color(0xFF4ECDC4)};
    } else if (purposeLower.contains('cab') || purposeLower.contains('taxi')) {
      return {'icon': Icons.local_taxi, 'color': const Color(0xFFF7B801)};
    } else if (purposeLower.contains('service')) {
      return {'icon': Icons.build, 'color': const Color(0xFF95E1D3)};
    } else if (purposeLower.contains('food')) {
      return {'icon': Icons.restaurant, 'color': const Color(0xFFFF8B94)};
    } else if (purposeLower.contains('courier')) {
      return {'icon': Icons.mail, 'color': const Color(0xFF9B59B6)};
    } else if (purposeLower.contains('doctor')) {
      return {'icon': Icons.medical_services, 'color': const Color(0xFF3498DB)};
    } else if (purposeLower.contains('plumber')) {
      return {'icon': Icons.plumbing, 'color': const Color(0xFF2ECC71)};
    } else if (purposeLower.contains('electrician')) {
      return {'icon': Icons.electrical_services, 'color': const Color(0xFFE74C3C)};
    } else if (purposeLower.contains('carpenter')) {
      return {'icon': Icons.carpenter, 'color': const Color(0xFF8E44AD)};
    } else if (purposeLower.contains('cleaning')) {
      return {'icon': Icons.cleaning_services, 'color': const Color(0xFF1ABC9C)};
    } else {
      return {'icon': Icons.more_horiz, 'color': const Color(0xFF7F8C8D)};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: const Text(
          'My Visitors',
          style: TextStyle(
            color: Color(0xFF1A1D1F),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1D1F)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryOrange,
          labelColor: AppTheme.primaryOrange,
          unselectedLabelColor: AppTheme.textGray,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllVisitors,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingList(),
                _buildActiveList(),
                _buildHistoryList(),
              ],
            ),
    );
  }

  Widget _buildPendingList() {
    final pendingVisitors = _allVisitors.where((v) => v['status'] == 'pending').toList();

    if (pendingVisitors.isEmpty) {
      return _buildEmptyState('No pending visitors');
    }

    return RefreshIndicator(
      onRefresh: _fetchAllVisitors,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pendingVisitors.length,
        itemBuilder: (context, index) {
          final visitor = pendingVisitors[index];
          return _buildVisitorCard(
            visitor: visitor,
            showActions: true,
          );
        },
      ),
    );
  }

  Widget _buildActiveList() {
    final activeVisitors = _allVisitors.where((v) {
      final status = v['status'];
      return status == 'accepted' || status == 'checked_in';
    }).toList();

    if (activeVisitors.isEmpty) {
      return _buildEmptyState('No active visitors');
    }

    return RefreshIndicator(
      onRefresh: _fetchAllVisitors,
      child: _buildDaySegregatedList(
        visitors: activeVisitors,
        displayCount: _activeDisplayCount,
        onLoadMore: () {
          setState(() {
            _activeDisplayCount += 10;
          });
        },
      ),
    );
  }

  Widget _buildHistoryList() {
    final historyVisitors = _allVisitors.where((v) {
      final status = v['status'];
      return status == 'checked_out' || status == 'denied';
    }).toList();

    if (historyVisitors.isEmpty) {
      return _buildEmptyState('No visitor history');
    }

    return RefreshIndicator(
      onRefresh: _fetchAllVisitors,
      child: _buildDaySegregatedList(
        visitors: historyVisitors,
        displayCount: _historyDisplayCount,
        onLoadMore: () {
          setState(() {
            _historyDisplayCount += 10;
          });
        },
      ),
    );
  }

  Widget _buildDaySegregatedList({
    required List<Map<String, dynamic>> visitors,
    required int displayCount,
    required VoidCallback onLoadMore,
  }) {
    final groupedVisitors = _groupVisitorsByDay(visitors, displayCount);
    final hasMore = displayCount < visitors.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Day-by-day grouped visitors
          ...groupedVisitors.entries.map((entry) {
            final date = DateTime.parse(entry.key);
            final dateLabel = _getDateLabel(date);
            final dayVisitors = entry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6F767E),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Visitors for this day
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: dayVisitors.map((visitor) => _buildVisitorCard(
                      visitor: visitor,
                      showActions: false,
                    )).toList(),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            );
          }),

          // Load More button
          if (hasMore) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onLoadMore,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppTheme.primaryOrange.withOpacity(0.3)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Load More',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${visitors.length - displayCount} more)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupVisitorsByDay(
    List<Map<String, dynamic>> visitors,
    int displayCount,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (var visitor in visitors.take(displayCount)) {
      final expectedStart = visitor['expected_start'] ?? visitor['created_at'];
      final date = DateTime.parse(expectedStart);
      final dateKey = DateFormat('yyyy-MM-dd').format(date);

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(visitor);
    }

    return grouped;
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) {
      return 'TODAY';
    } else if (compareDate == yesterday) {
      return 'YESTERDAY';
    } else {
      return DateFormat('EEEE, MMM dd, yyyy').format(date).toUpperCase();
    }
  }

  Widget _buildVisitorCard({
    required Map<String, dynamic> visitor,
    required bool showActions,
  }) {
    final expectedStart = DateTime.parse(visitor['expected_start'] ?? visitor['created_at']);
    final timeStr = DateFormat('hh:mm a').format(expectedStart);
    final name = visitor['visitor_name'] ?? 'Unknown';
    final purpose = visitor['purpose'] ?? 'Unknown';
    final phone = visitor['visitor_phone'] ?? 'N/A';
    final status = visitor['status'] ?? 'pending';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'accepted':
        statusColor = AppTheme.successGreen;
        statusText = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case 'denied':
        statusColor = AppTheme.errorRed;
        statusText = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      case 'pending':
        statusColor = AppTheme.warningAmber;
        statusText = 'Pending';
        statusIcon = Icons.schedule;
        break;
      case 'checked_in':
        statusColor = AppTheme.successGreen;
        statusText = 'In';
        statusIcon = Icons.login;
        break;
      case 'checked_out':
        statusColor = const Color(0xFF6F767E);
        statusText = 'Out';
        statusIcon = Icons.logout;
        break;
      default:
        statusColor = const Color(0xFF6F767E);
        statusText = 'Unknown';
        statusIcon = Icons.help_outline;
    }

    final purposeData = _getPurposeIconAndColor(purpose);
    final purposeIcon = purposeData['icon'] as IconData;
    final purposeColor = purposeData['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF4), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar with purpose icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: purposeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      purposeIcon,
                      color: purposeColor,
                      size: 24,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D1F),
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              purpose,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryOrange,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '· $timeStr',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Status
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

            // Phone number
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone, size: 14, color: Color(0xFF6F767E)),
                const SizedBox(width: 6),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6F767E),
                  ),
                ),
              ],
            ),

            // Actions
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectVisitor(visitor['id']),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: const BorderSide(color: AppTheme.errorRed),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveVisitor(visitor['id']),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: AppTheme.textGray.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textGray.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveVisitor(String visitorId) async {
    try {
      final apiClient = ref.read(apiClientProvider);

      final response = await apiClient.post(
        '/visitors/$visitorId/respond',
        data: {
          'decision': 'accept',
        },
      );

      if (response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visitor approved successfully'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
        _fetchAllVisitors(); // Refresh list
      } else {
        throw Exception('Failed to approve visitor');
      }
    } catch (e) {
      debugPrint('❌ Error approving visitor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve visitor: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _rejectVisitor(String visitorId) async {
    try {
      final apiClient = ref.read(apiClientProvider);

      final response = await apiClient.post(
        '/visitors/$visitorId/respond',
        data: {
          'decision': 'deny',
        },
      );

      if (response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visitor rejected'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
        _fetchAllVisitors(); // Refresh list
      } else {
        throw Exception('Failed to reject visitor');
      }
    } catch (e) {
      debugPrint('❌ Error rejecting visitor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject visitor: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}
