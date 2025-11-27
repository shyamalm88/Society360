import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import '../../../data/models/metadata_models.dart';

class MyVisitorsScreen extends ConsumerStatefulWidget {
  const MyVisitorsScreen({super.key});

  @override
  ConsumerState<MyVisitorsScreen> createState() => _MyVisitorsScreenState();
}

class _MyVisitorsScreenState extends ConsumerState<MyVisitorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Visitors'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentBlue,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
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
    // Mock data - in real app, fetch from API
    final pendingVisitors = [
      Visitor(
        id: '1',
        name: 'Raj Kumar',
        phone: '+919876543210',
        purpose: 'Guest Visit',
        expectedArrival: DateTime.now().add(const Duration(hours: 2)),
        status: 'pending',
        createdAt: DateTime.now(),
      ),
      Visitor(
        id: '2',
        name: 'Plumber - Kumar',
        phone: '+919876543211',
        vehicleNumber: 'KA01AB1234',
        purpose: 'Service',
        expectedArrival: DateTime.now().add(const Duration(hours: 4)),
        status: 'pending',
        createdAt: DateTime.now(),
      ),
    ];

    if (pendingVisitors.isEmpty) {
      return _buildEmptyState('No pending visitors');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingVisitors.length,
      itemBuilder: (context, index) {
        final visitor = pendingVisitors[index];
        return _buildVisitorCard(
          visitor: visitor,
          showActions: true,
        );
      },
    );
  }

  Widget _buildActiveList() {
    // Mock data - in real app, fetch from API
    final activeVisitors = [
      Visitor(
        id: '3',
        name: 'Amazon Delivery',
        phone: '+919876543212',
        purpose: 'Delivery',
        expectedArrival: DateTime.now().subtract(const Duration(minutes: 10)),
        status: 'approved',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];

    if (activeVisitors.isEmpty) {
      return _buildEmptyState('No active visitors');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeVisitors.length,
      itemBuilder: (context, index) {
        final visitor = activeVisitors[index];
        return _buildVisitorCard(
          visitor: visitor,
          showActions: false,
        );
      },
    );
  }

  Widget _buildHistoryList() {
    // Mock data - in real app, fetch from API
    final historyVisitors = [
      Visitor(
        id: '4',
        name: 'Food Delivery - Swiggy',
        phone: '+919876543213',
        purpose: 'Delivery',
        expectedArrival: DateTime.now().subtract(const Duration(hours: 5)),
        status: 'completed',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      Visitor(
        id: '5',
        name: 'Electrician - Mohan',
        phone: '+919876543214',
        vehicleNumber: 'KA02XY9876',
        purpose: 'Service',
        expectedArrival: DateTime.now().subtract(const Duration(days: 1)),
        status: 'completed',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    if (historyVisitors.isEmpty) {
      return _buildEmptyState('No visitor history');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: historyVisitors.length,
      itemBuilder: (context, index) {
        final visitor = historyVisitors[index];
        return _buildVisitorCard(
          visitor: visitor,
          showActions: false,
        );
      },
    );
  }

  Widget _buildVisitorCard({
    required Visitor visitor,
    required bool showActions,
  }) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (visitor.status) {
      case 'pending':
        statusColor = AppTheme.warningAmber;
        statusText = 'Pending';
        statusIcon = Icons.schedule;
        break;
      case 'approved':
        statusColor = AppTheme.successGreen;
        statusText = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = AppTheme.errorRed;
        statusText = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      case 'completed':
        statusColor = AppTheme.textMuted;
        statusText = 'Completed';
        statusIcon = Icons.done_all;
        break;
      default:
        statusColor = AppTheme.textMuted;
        statusText = 'Unknown';
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        visitor.purpose,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  text: statusText,
                  color: statusColor,
                  icon: statusIcon,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Details
            _buildInfoRow(Icons.phone, visitor.phone),
            if (visitor.vehicleNumber != null) ...[
              const SizedBox(height: 6),
              _buildInfoRow(Icons.directions_car, visitor.vehicleNumber!),
            ],
            const SizedBox(height: 6),
            _buildInfoRow(
              Icons.access_time,
              _formatDateTime(visitor.expectedArrival),
            ),

            // Actions
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectVisitor(visitor.id),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: const BorderSide(color: AppTheme.errorRed),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveVisitor(visitor.id),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
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
            color: AppTheme.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.isNegative) {
      final absDiff = difference.abs();
      if (absDiff.inMinutes < 60) {
        return '${absDiff.inMinutes} minutes ago';
      } else if (absDiff.inHours < 24) {
        return '${absDiff.inHours} hours ago';
      }
    } else {
      if (difference.inMinutes < 60) {
        return 'In ${difference.inMinutes} minutes';
      } else if (difference.inHours < 24) {
        return 'In ${difference.inHours} hours';
      }
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _approveVisitor(String visitorId) async {
    // TODO: Call API to approve visitor
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Visitor approved successfully'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
    setState(() {});
  }

  Future<void> _rejectVisitor(String visitorId) async {
    // TODO: Call API to reject visitor
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Visitor rejected'),
        backgroundColor: AppTheme.errorRed,
      ),
    );
    setState(() {});
  }
}
