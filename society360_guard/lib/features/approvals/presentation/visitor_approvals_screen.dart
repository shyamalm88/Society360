import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/socket_service_provider.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/app_initialization_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/visitor_service.dart';
import 'widgets/visitor_approval_card.dart';

/// Visitor Approvals Screen for Guard App
/// Shows approved, rejected, and auto-rejected visitors
class VisitorApprovalsScreen extends ConsumerStatefulWidget {
  const VisitorApprovalsScreen({super.key});

  @override
  ConsumerState<VisitorApprovalsScreen> createState() =>
      _VisitorApprovalsScreenState();
}

class _VisitorApprovalsScreenState
    extends ConsumerState<VisitorApprovalsScreen> with SingleTickerProviderStateMixin {
  late final VisitorService _visitorService;
  late final ProfileService _profileService;
  late final SocketService _socketService;
  late TabController _tabController;

  List<Map<String, dynamic>> _approvedVisitors = [];
  List<Map<String, dynamic>> _rejectedVisitors = [];
  List<Map<String, dynamic>> _autoRejectedVisitors = [];

  bool _isLoading = true;
  int _currentTabIndex = 0;

  // Profile data
  String? _guardId;
  String? _societyId;
  String? _userId;

  @override
  void initState() {
    super.initState();
    // Initialize services with ApiClient from provider
    final apiClient = ref.read(apiClientProvider);
    _visitorService = VisitorService(apiClient);
    _profileService = ProfileService(apiClient);

    // Initialize TabController
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });

    // Get profile data from app initialization service
    final appInitService = ref.read(appInitializationServiceProvider);
    final profileData = appInitService.getProfileData();
    _guardId = profileData['guardId'];
    _societyId = profileData['societyId'];
    _userId = profileData['userId'];

    _setupSocketListeners();
    _fetchVisitors();
  }

  /// Set up Socket.io event listeners for this screen
  void _setupSocketListeners() {
    // Get singleton Socket.io service (already connected by app initialization)
    // Cache it to avoid accessing ref in dispose()
    _socketService = ref.read(socketServiceProvider);

    debugPrint('📋 Approvals Screen: Setting up Socket.io listeners');

    // Add approvals-specific listeners for approval events
    _socketService.addApprovalListener(_handleApprovalEvent);

    // Add approvals-specific listeners for timeout events
    _socketService.addTimeoutListener(_handleTimeoutEvent);

    // Add check-in listener to update visitor status in real-time
    _socketService.addCheckinListener(_handleCheckinEvent);

    // Add checkout listener to remove visitor from approved list in real-time
    _socketService.addCheckoutListener(_handleCheckoutEvent);

    debugPrint('✅ Approvals Screen: Socket.io listeners registered');
  }

  void _handleApprovalEvent(Map<String, dynamic> data) {
    final decision = data['decision'];

    setState(() {
      if (decision == 'accept') {
        _approvedVisitors.insert(0, data);
      } else {
        _rejectedVisitors.insert(0, data);
      }
    });

    // Show snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'accept'
                ? '✅ ${data['visitor_name']} approved by ${data['approver_name']}'
                : '❌ ${data['visitor_name']} rejected by ${data['approver_name']}',
          ),
          backgroundColor: decision == 'accept' ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _handleTimeoutEvent(Map<String, dynamic> data) {
    setState(() {
      _autoRejectedVisitors.insert(0, data);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏱️ Visitor request timed out'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _handleCheckinEvent(Map<String, dynamic> data) {
    debugPrint('📋 Approvals Screen: Check-in event received: $data');

    setState(() {
      // Find the visitor in the approved list and update their status
      final visitorId = data['visitor_id'];
      final index = _approvedVisitors.indexWhere(
        (v) => (v['visitor_id'] ?? v['id']) == visitorId,
      );

      if (index != -1) {
        _approvedVisitors[index]['status'] = 'checked_in';
        _approvedVisitors[index]['visit_id'] = data['visit_id'];
        debugPrint('📋 Updated visitor status to checked_in: ${_approvedVisitors[index]['visitor_name']}');
      }
    });
  }

  void _handleCheckoutEvent(Map<String, dynamic> data) {
    debugPrint('📋 Approvals Screen: Checkout event received: $data');

    setState(() {
      // Remove the visitor from the approved list
      final visitorId = data['visitor_id'];
      final sizeBefore = _approvedVisitors.length;

      _approvedVisitors.removeWhere(
        (v) => (v['visitor_id'] ?? v['id']) == visitorId,
      );

      if (_approvedVisitors.length < sizeBefore) {
        debugPrint('📋 Removed checked-out visitor from approved list');
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('👋 ${data['visitor_name'] ?? 'Visitor'} checked out'),
          backgroundColor: Colors.purple,
        ),
      );
    }
  }

  Future<void> _fetchVisitors() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('📋 Approvals Screen: Fetching visitors...');
      // Fetch visitors by different statuses
      final accepted = await _visitorService.fetchVisitorsByStatus('accepted');
      final checkedIn = await _visitorService.fetchVisitorsByStatus('checked_in');
      final rejected = await _visitorService.fetchVisitorsByStatus('denied');

      // Combine accepted and checked_in visitors in the approved list
      final approved = [...accepted, ...checkedIn];

      debugPrint('📋 Approvals Screen: Received ${accepted.length} accepted visitors');
      debugPrint('📋 Approvals Screen: Received ${checkedIn.length} checked-in visitors');
      debugPrint('📋 Approvals Screen: Total approved: ${approved.length}');
      debugPrint('📋 Approvals Screen: Approved visitors: ${approved.map((v) => v['visitor_name']).join(', ')}');
      debugPrint('📋 Approvals Screen: Received ${rejected.length} rejected visitors');

      // Note: Since timeout field doesn't exist in DB schema,
      // all rejected visitors will be shown in the rejected tab for now
      final rejectedList = rejected;
      final autoRejectedList = <Map<String, dynamic>>[];

      debugPrint('📋 Approvals Screen: Rejected (manual): ${rejectedList.length}');
      debugPrint('📋 Approvals Screen: Rejected (timeout): ${autoRejectedList.length}');

      setState(() {
        _approvedVisitors = approved;
        _rejectedVisitors = rejectedList;
        _autoRejectedVisitors = autoRejectedList;
        _isLoading = false;
      });

      debugPrint('✅ Approvals Screen: Updated lists - Approved: ${_approvedVisitors.length}, Rejected: ${_rejectedVisitors.length}, Timeout: ${_autoRejectedVisitors.length}');
    } catch (e) {
      debugPrint('❌ Approvals Screen: Error fetching visitors: $e');
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

  Future<void> _clearRejectedVisitors() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Rejected Visitors'),
        content: Text(
          'Are you sure you want to clear all ${_rejectedVisitors.length} rejected visitor(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Call API to clear rejected visitors
      final result = await _visitorService.clearRejectedVisitors();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Clear the rejected list
        setState(() {
          _rejectedVisitors.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Cleared ${result['deleted_count']} rejected visitor(s)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to clear: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkInVisitor(Map<String, dynamic> visitor) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get guard ID
      if (_guardId == null) {
        throw Exception('Guard ID not available. Please restart the app.');
      }

      // Call check-in API
      final result = await _visitorService.checkInVisitor(
        visitorId: visitor['visitor_id'] ?? visitor['id'],
        guardId: _guardId!,
        notes: 'Checked in via Approvals screen',
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Update visitor status to 'checked_in' instead of removing
        setState(() {
          final index = _approvedVisitors.indexWhere(
            (v) => (v['visitor_id'] ?? v['id']) == (visitor['visitor_id'] ?? visitor['id']),
          );
          if (index != -1) {
            _approvedVisitors[index]['status'] = 'checked_in';
            // Store visit_id from the response for checkout
            // Backend returns visit record with 'id' field (which is the visit_id)
            if (result['id'] != null) {
              _approvedVisitors[index]['visit_id'] = result['id'];
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${visitor['visitor_name']} checked in successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to check in: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkOutVisitor(Map<String, dynamic> visitor) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get visit ID (required for checkout)
      final visitId = visitor['visit_id'];
      if (visitId == null) {
        throw Exception('Visit ID not available. Cannot checkout visitor.');
      }

      // Call check-out API
      await _visitorService.checkOutVisitor(
        visitId: visitId,
        guardId: _guardId,
        notes: 'Checked out via Approvals screen',
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Remove visitor from approved list after checkout
        setState(() {
          _approvedVisitors.removeWhere(
            (v) => (v['visitor_id'] ?? v['id']) == (visitor['visitor_id'] ?? visitor['id']),
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${visitor['visitor_name']} checked out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to check out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Remove Socket.io listeners using cached instance (don't access ref after dispose)
    _socketService.removeApprovalListener(_handleApprovalEvent);
    _socketService.removeTimeoutListener(_handleTimeoutEvent);
    _socketService.removeCheckinListener(_handleCheckinEvent);
    _socketService.removeCheckoutListener(_handleCheckoutEvent);
    _tabController.dispose();

    // Don't disconnect the socket - it's a singleton managed by the provider
    // The socket should stay connected throughout the app lifecycle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Visitor Approvals',
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
            onPressed: _fetchVisitors,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchVisitors,
              child: Column(
                children: [
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AppTheme.primaryOrange,
                        indicatorWeight: 3,
                        labelColor: AppTheme.primaryOrange,
                        unselectedLabelColor: const Color(0xFF6F767E),
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: [
                          Tab(
                            text: 'Approved (${_approvedVisitors.length})',
                            icon: const Icon(Icons.check_circle, size: 20),
                          ),
                          Tab(
                            text: 'Rejected (${_rejectedVisitors.length})',
                            icon: const Icon(Icons.cancel, size: 20),
                          ),
                          Tab(
                            text: 'Timeout (${_autoRejectedVisitors.length})',
                            icon: const Icon(Icons.timer_off, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildApprovedList(),
                          _buildRejectedList(),
                          _buildAutoRejectedList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildApprovedList() {
    if (_approvedVisitors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No approved visitors',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _approvedVisitors.length,
      itemBuilder: (context, index) {
        final visitor = _approvedVisitors[index];
        return _buildApprovedCard(visitor);
      },
    );
  }

  Widget _buildApprovedCard(Map<String, dynamic> visitor) {
    return VisitorApprovalCard(
      visitor: visitor,
      onCheckIn: () => _checkInVisitor(visitor),
      onCheckOut: () => _checkOutVisitor(visitor),
    );
  }

  Widget _buildRejectedList() {
    if (_rejectedVisitors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No rejected visitors',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Clear button at the top of rejected list
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _clearRejectedVisitors,
              icon: const Icon(Icons.delete_outline, size: 20),
              label: Text('Clear All (${_rejectedVisitors.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.red.shade200),
                ),
              ),
            ),
          ),
        ),
        // List of rejected visitors
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _rejectedVisitors.length,
            itemBuilder: (context, index) {
              final visitor = _rejectedVisitors[index];
              return _buildRejectedCard(visitor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRejectedCard(Map<String, dynamic> visitor) {
    return VisitorRejectedCard(
      visitor: visitor,
      isAutoRejected: false,
    );
  }

  Widget _buildAutoRejectedList() {
    if (_autoRejectedVisitors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_off_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No auto-rejected visitors',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _autoRejectedVisitors.length,
      itemBuilder: (context, index) {
        final visitor = _autoRejectedVisitors[index];
        return _buildAutoRejectedCard(visitor);
      },
    );
  }

  Widget _buildAutoRejectedCard(Map<String, dynamic> visitor) {
    return VisitorRejectedCard(
      visitor: visitor,
      isAutoRejected: true,
    );
  }
}
