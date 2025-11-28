import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/visitor_service.dart';
import '../../../core/services/app_initialization_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/socket_service_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with WidgetsBindingObserver {
  late final SocketService _socketService;

  int _approvedCount = 0;
  int _rejectedCount = 0;
  int _autoRejectedCount = 0;
  bool _isLoadingCounts = true;
  bool _isInitialized = false;

  // Today's Visitors
  List<Map<String, dynamic>> _todaysVisitors = [];
  bool _isLoadingTodaysVisitors = true;

  // Recent Activity
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoadingRecentActivity = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🏠 Dashboard: initState called');
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    _fetchApprovalCounts();
    _fetchTodaysVisitors();
    _fetchRecentActivity();
  }

  /// Initialize app services (Socket.io, FCM) on first load
  Future<void> _initializeApp() async {
    try {
      final appInitService = ref.read(appInitializationServiceProvider);
      await appInitService.initialize();

      // Set up Socket.io event listeners for real-time dashboard updates
      // Cache it to avoid accessing ref in dispose()
      _socketService = ref.read(socketServiceProvider);

      // Add dashboard-specific listeners for approval events
      _socketService.addApprovalListener(_handleApprovalEvent);

      // Add dashboard-specific listeners for timeout events
      _socketService.addTimeoutListener(_handleTimeoutEvent);

      // Add dashboard-specific listeners for rejected visitors cleared events
      _socketService.addRejectedClearedListener(_handleRejectedClearedEvent);

      // Add dashboard-specific listeners for check-in events
      _socketService.addCheckinListener(_handleCheckinEvent);

      // Add dashboard-specific listeners for checkout events
      _socketService.addCheckoutListener(_handleCheckoutEvent);

      debugPrint('✅ Dashboard: Socket.io listeners registered');
    } catch (e) {
      debugPrint('❌ Dashboard: Error initializing app: $e');
    }
  }

  /// Handle visitor approval/rejection events from Socket.io
  void _handleApprovalEvent(Map<String, dynamic> data) {
    debugPrint('🏠 Dashboard: Received visitor approval event: $data');
    if (mounted) {
      _fetchApprovalCounts();
      _fetchTodaysVisitors();
      _fetchRecentActivity();
    }
  }

  /// Handle visitor timeout events from Socket.io
  void _handleTimeoutEvent(Map<String, dynamic> data) {
    debugPrint('🏠 Dashboard: Received visitor timeout event: $data');
    if (mounted) {
      _fetchApprovalCounts();
      _fetchTodaysVisitors();
      _fetchRecentActivity();
    }
  }

  /// Handle rejected visitors cleared event from Socket.io
  void _handleRejectedClearedEvent(Map<String, dynamic> data) {
    debugPrint('🏠 Dashboard: Received rejected visitors cleared event: $data');
    if (mounted) {
      _fetchApprovalCounts();
      _fetchTodaysVisitors();
      _fetchRecentActivity();

      // Show a snackbar to notify the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ Rejected visitors cleared (${data['deleted_count']} removed)'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Handle visitor check-in events from Socket.io
  void _handleCheckinEvent(Map<String, dynamic> data) {
    debugPrint('🏠 Dashboard: Received visitor check-in event: $data');
    if (mounted) {
      _fetchApprovalCounts();
      _fetchTodaysVisitors();
      _fetchRecentActivity();
    }
  }

  /// Handle visitor checkout events from Socket.io
  void _handleCheckoutEvent(Map<String, dynamic> data) {
    debugPrint('🏠 Dashboard: Received visitor checkout event: $data');
    if (mounted) {
      _fetchApprovalCounts();
      _fetchTodaysVisitors();
      _fetchRecentActivity();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('🏠 Dashboard: didChangeDependencies called (isInitialized: $_isInitialized)');

    // Only refresh on subsequent calls (when navigating back), not during initial build
    if (_isInitialized) {
      debugPrint('🔄 Dashboard: Refreshing counts (navigated back to screen)');
      _fetchApprovalCounts();
      _fetchTodaysVisitors();
      _fetchRecentActivity();
    } else {
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    // Remove Socket.io listeners using cached instance (don't access ref after dispose)
    _socketService.removeApprovalListener(_handleApprovalEvent);
    _socketService.removeTimeoutListener(_handleTimeoutEvent);
    _socketService.removeRejectedClearedListener(_handleRejectedClearedEvent);
    _socketService.removeCheckinListener(_handleCheckinEvent);
    _socketService.removeCheckoutListener(_handleCheckoutEvent);

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh counts when app comes back to foreground
      _fetchApprovalCounts();
      _fetchTodaysVisitors();
      _fetchRecentActivity();
    }
  }

  Future<void> _fetchApprovalCounts() async {
    try {
      debugPrint('🔄 Dashboard: Fetching approval counts...');
      final apiClient = ref.read(apiClientProvider);
      final visitorService = VisitorService(apiClient);

      final approved = await visitorService.fetchVisitorsByStatus('accepted');
      final rejected = await visitorService.fetchVisitorsByStatus('denied');

      debugPrint('📊 Dashboard: Received ${approved.length} approved visitors');
      debugPrint('📊 Dashboard: Approved visitors: ${approved.map((v) => v['visitor_name']).join(', ')}');
      debugPrint('📊 Dashboard: Received ${rejected.length} rejected visitors');

      final rejectedCount = rejected.where((v) => v['timeout'] != true).length;
      final timeoutCount = rejected.where((v) => v['timeout'] == true).length;

      debugPrint('📊 Dashboard: Rejected (manual): $rejectedCount');
      debugPrint('📊 Dashboard: Rejected (timeout): $timeoutCount');

      setState(() {
        _approvedCount = approved.length;
        _rejectedCount = rejectedCount;
        _autoRejectedCount = timeoutCount;
        _isLoadingCounts = false;
      });

      debugPrint('✅ Dashboard: Updated counts - Approved: $_approvedCount, Rejected: $_rejectedCount, Timeout: $_autoRejectedCount');
    } catch (e) {
      debugPrint('❌ Dashboard: Error fetching approval counts: $e');
      setState(() => _isLoadingCounts = false);
    }
  }

  Future<void> _fetchTodaysVisitors() async {
    try {
      debugPrint('🔄 Dashboard: Fetching today\'s visitors...');
      final apiClient = ref.read(apiClientProvider);
      final visitorService = VisitorService(apiClient);

      // Get all visitors (pending, accepted, denied)
      final allVisitors = await visitorService.fetchVisitors();

      // Filter for today's visitors (based on expected_start date)
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final todaysVisitorsList = allVisitors.where((visitor) {
        final expectedStart = visitor['expected_start'];
        if (expectedStart == null) return false;

        final visitDateTime = DateTime.parse(expectedStart);
        // Use >= and < comparison to include visitors at the start of the day
        return !visitDateTime.isBefore(todayStart) && visitDateTime.isBefore(todayEnd);
      }).toList();

      // Sort by expected time (latest first)
      todaysVisitorsList.sort((a, b) {
        final aTime = DateTime.parse(a['expected_start']);
        final bTime = DateTime.parse(b['expected_start']);
        return bTime.compareTo(aTime); // Descending order
      });

      debugPrint('📊 Dashboard: Found ${todaysVisitorsList.length} visitors for today');

      setState(() {
        _todaysVisitors = todaysVisitorsList;
        _isLoadingTodaysVisitors = false;
      });
    } catch (e) {
      debugPrint('❌ Dashboard: Error fetching today\'s visitors: $e');
      setState(() => _isLoadingTodaysVisitors = false);
    }
  }

  Future<void> _fetchRecentActivity() async {
    try {
      debugPrint('🔄 Dashboard: Fetching recent activity...');
      final apiClient = ref.read(apiClientProvider);
      final visitorService = VisitorService(apiClient);

      // Fetch recent visitors (last 10)
      final allVisitors = await visitorService.fetchVisitors();

      // Sort by updated_at (most recent first) and take last 10
      final recentList = allVisitors.toList();
      recentList.sort((a, b) {
        final aTime = DateTime.parse(a['updated_at'] ?? a['created_at']);
        final bTime = DateTime.parse(b['updated_at'] ?? b['created_at']);
        return bTime.compareTo(aTime); // Descending order
      });

      final recentActivities = recentList.take(10).toList();

      debugPrint('📊 Dashboard: Found ${recentActivities.length} recent activities');

      setState(() {
        _recentActivities = recentActivities;
        _isLoadingRecentActivity = false;
      });
    } catch (e) {
      debugPrint('❌ Dashboard: Error fetching recent activity: $e');
      setState(() => _isLoadingRecentActivity = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDate = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
    final currentTime = DateFormat('HH:mm').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFFFAFBFC),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Security Badge Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryOrange.withOpacity(0.15),
                          AppTheme.accentTeal.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: AppTheme.primaryOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // App Name & Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'SecureEntry Guard',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1D1F),
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          currentDate,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6F767E),
                            letterSpacing: 0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Notification Icon
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F5F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF1A1D1F),
                            size: 20,
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    onPressed: () => _showNotificationsSheet(context),
                  ),
                  const SizedBox(width: 4),
                  // Logout Icon
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFF1A1D1F),
                        size: 20,
                      ),
                    ),
                    onPressed: () async {
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );

                      if (shouldLogout == true) {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // 1. Visitor Approvals Summary Card
            _buildApprovalsSummaryCard(context),

            const SizedBox(height: 24),

            // 2. Quick Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D1F),
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    '4 available',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6F767E).withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickActionsGrid(context),

            const SizedBox(height: 28),

            // 3. Today's Visitors Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Today\'s Visitors',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1D1F),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_todaysVisitors.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      context.push('/all-visitors');
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'See All',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primaryOrange),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildTodaysVisitorsList(context),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalsSummaryCard(BuildContext context) {
    final approvedCount = _isLoadingCounts ? 0 : _approvedCount;
    final rejectedCount = _isLoadingCounts ? 0 : _rejectedCount;
    final autoRejectedCount = _isLoadingCounts ? 0 : _autoRejectedCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.how_to_vote_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visitor Approvals',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage pending requests',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push('/visitor-approvals'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildApprovalCountBadge(
                    label: 'Approved',
                    count: approvedCount,
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                    bgColor: const Color(0xFFD1FAE5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildApprovalCountBadge(
                    label: 'Rejected',
                    count: rejectedCount,
                    icon: Icons.cancel_rounded,
                    color: const Color(0xFFEF4444),
                    bgColor: const Color(0xFFFEE2E2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildApprovalCountBadge(
                    label: 'Timeout',
                    count: autoRejectedCount,
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFFF59E0B),
                    bgColor: const Color(0xFFFEF3C7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalCountBadge({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysVisitorsList(BuildContext context) {
    if (_isLoadingTodaysVisitors) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_todaysVisitors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8ECF4), width: 1),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.event_available, size: 48, color: AppTheme.textGray.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text(
                  'No visitors expected today',
                  style: TextStyle(
                    color: AppTheme.textGray.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show max 3 visitors on dashboard
    final displayCount = _todaysVisitors.length > 3 ? 3 : _todaysVisitors.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: displayCount,
        itemBuilder: (context, index) {
          final visitor = _todaysVisitors[index];
          final expectedStart = DateTime.parse(visitor['expected_start']);
          final timeStr = DateFormat('hh:mm a').format(expectedStart);

          return _buildTodaysVisitorCard(
            context: context,
            time: timeStr,
            name: visitor['visitor_name'] ?? 'Unknown',
            purpose: visitor['purpose'] ?? 'Unknown',
            flat: visitor['flat_number'] ?? 'N/A',
            status: visitor['status'] ?? 'pending',
          );
        },
      ),
    );
  }

  /// Get icon and color based on visitor purpose (matches visitor entry dropdown exactly)
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

  Widget _buildTodaysVisitorCard({
    required BuildContext context,
    required String time,
    required String name,
    required String purpose,
    required String flat,
    required String status,
  }) {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showVisitorDetails(context, name, purpose, flat),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                          Flexible(
                            child: Row(
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
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    flat,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF6F767E),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '· $time',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
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
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final actions = [
      {
        'icon': Icons.person_add_rounded,
        'label': 'New Entry',
        'subtitle': 'Register visitor',
        'color': const Color(0xFF0EA5E9), // Sky Blue
        'bgColor': const Color(0xFFE0F2FE),
        'onTap': () => context.push('/visitor-entry'),
      },
      {
        'icon': Icons.check_circle_rounded,
        'label': 'Approvals',
        'subtitle': 'View status',
        'color': const Color(0xFF10B981), // Green
        'bgColor': const Color(0xFFD1FAE5),
        'onTap': () => context.push('/visitor-approvals'),
      },
      {
        'icon': Icons.qr_code_scanner_rounded,
        'label': 'Scan QR',
        'subtitle': 'Quick check-in',
        'color': const Color(0xFFF59E0B), // Amber
        'bgColor': const Color(0xFFFEF3C7),
        'onTap': () => _showQRScanner(context),
      },
      {
        'icon': Icons.search_rounded,
        'label': 'Search',
        'subtitle': 'Find visitor',
        'color': const Color(0xFF8B5CF6), // Purple
        'bgColor': const Color(0xFFF3E8FF),
        'onTap': () => _showSearchDialog(context),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          final color = action['color'] as Color;
          final bgColor = action['bgColor'] as Color;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: action['onTap'] as VoidCallback,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        action['icon'] as IconData,
                        size: 24,
                        color: color,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action['label'] as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          action['subtitle'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentEntriesList(BuildContext context) {
    if (_isLoadingRecentActivity) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_recentActivities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history, size: 48, color: AppTheme.textGray.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                'No recent activity',
                style: TextStyle(
                  color: AppTheme.textGray.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _recentActivities.length,
      itemBuilder: (context, index) {
        final visitor = _recentActivities[index];
        final updatedAt = DateTime.parse(visitor['updated_at'] ?? visitor['created_at']);
        final now = DateTime.now();
        final difference = now.difference(updatedAt);

        String timeStr;
        if (difference.inMinutes < 60) {
          timeStr = '${difference.inMinutes}m ago';
        } else if (difference.inHours < 24) {
          timeStr = '${difference.inHours}h ago';
        } else {
          timeStr = '${difference.inDays}d ago';
        }

        return _buildVisitorCard(
          context: context,
          time: timeStr,
          name: visitor['visitor_name'] ?? 'Unknown',
          purpose: visitor['purpose'] ?? 'Unknown',
          flat: visitor['flat_number'] ?? 'N/A',
          status: visitor['status'] ?? 'pending',
          isFrequent: false,
        );
      },
    );
  }

  Widget _buildVisitorCard({
    required BuildContext context,
    required String time,
    required String name,
    required String purpose,
    required String flat,
    required String status,
    required bool isFrequent,
  }) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'checked_in':
        statusColor = const Color(0xFF10B981);
        statusText = 'In';
        statusIcon = Icons.login;
        break;
      case 'checked_out':
        statusColor = const Color(0xFF6F767E);
        statusText = 'Out';
        statusIcon = Icons.logout;
        break;
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
      default:
        statusColor = const Color(0xFF6F767E);
        statusText = 'Unknown';
        statusIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF4), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showVisitorDetails(context, name, purpose, flat),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1D1F),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1D1F),
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          if (isFrequent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.star, size: 10, color: Color(0xFFF59E0B)),
                                  SizedBox(width: 2),
                                  Text(
                                    'VIP',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFF59E0B),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
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
                            flat,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6F767E),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '· $time',
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
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQRScanner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECF4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_scanner, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Scan QR Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D1F),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF10B981), width: 2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(Icons.qr_code_scanner, size: 100, color: Color(0xFFE8ECF4)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Position QR code within frame',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6F767E), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('QR Code scanned successfully!')),
                        );
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Open Camera Scanner'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFrequentVisitors(BuildContext context) {
    final frequentVisitors = [
      {'name': 'Priya Sharma', 'visits': '24', 'lastVisit': 'Today'},
      {'name': 'Sanjay Reddy', 'visits': '18', 'lastVisit': 'Yesterday'},
      {'name': 'Amazon Delivery', 'visits': '15', 'lastVisit': '2 days ago'},
      {'name': 'Swiggy', 'visits': '12', 'lastVisit': 'Today'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECF4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.star, color: Color(0xFFF59E0B), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Frequent Visitors',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D1F),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: frequentVisitors.length,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemBuilder: (context, index) {
                  final visitor = frequentVisitors[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            visitor['name']![0],
                            style: const TextStyle(
                              color: Color(0xFF1A1D1F),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        visitor['name']!,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${visitor['visits']} visits · Last: ${visitor['lastVisit']}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6F767E)),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.star, color: Color(0xFFF59E0B), size: 20),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${visitor['name']} unmarked as frequent')),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Visitors'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter name or phone number',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search results will appear here')),
              );
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showVisitorDetails(BuildContext context, String name, String purpose, String flat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECF4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D1F),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D1F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$purpose · $flat',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6F767E), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$name marked as frequent visitor')),
                      );
                    },
                    icon: const Icon(Icons.star_border, size: 18),
                    label: const Text('Mark VIP'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$name checked out')),
                      );
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Check Out'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    final notifications = [
      {
        'title': 'New visitor waiting',
        'message': 'Rajesh Kumar is waiting at Gate A',
        'time': '2 mins ago',
        'icon': Icons.person_add,
        'color': AppTheme.primaryOrange,
      },
      {
        'title': 'Delivery arrived',
        'message': 'Amazon package for B-205',
        'time': '15 mins ago',
        'icon': Icons.local_shipping,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Shift reminder',
        'message': 'Your shift ends in 2 hours',
        'time': '1 hour ago',
        'icon': Icons.access_time,
        'color': const Color(0xFFF59E0B),
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECF4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications, color: AppTheme.primaryOrange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D1F),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Clear all', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (notif['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          notif['icon'] as IconData,
                          color: notif['color'] as Color,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        notif['title']! as String,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notif['message']! as String,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notif['time']! as String,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
