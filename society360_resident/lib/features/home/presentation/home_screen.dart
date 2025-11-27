import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../config/theme.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/socket/socket_service.dart';
import '../../../data/repositories/visitor_repository.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../guest_access/presentation/create_guest_pass_screen.dart';
import '../../guest_access/presentation/my_visitors_screen.dart';
import '../../visitor_approvals/presentation/visitor_approvals_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeTabScreen(),
    const MyVisitorsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initSocketConnection();
  }

  /// Initialize Socket.io connection and join flat room
  void _initSocketConnection() {
    // Wait for next frame to access providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(storageServiceProvider);
      final socketService = ref.read(socketServiceProvider);

      // Get flat ID from storage
      final flatId = storage.flatId;

      if (flatId != null && flatId.isNotEmpty) {
        debugPrint('🔌 Initializing socket connection for flat: $flatId');

        // Connect to socket server
        socketService.connect();

        // Join flat room
        socketService.joinRoom('flat', flatId);

        // NOTE: Socket.io visitor dialog DISABLED - relying on FCM push notifications instead
        // Visitor requests will now come via FCM system notifications only
        // This ensures notifications work even when the app is closed

        // // Listen for visitor requests (DISABLED - use FCM instead)
        // socketService.onVisitorRequest = (data) {
        //   debugPrint('🔔 Visitor request received: $data');
        //   _showVisitorRequestDialog(data);
        // };
      } else {
        debugPrint('⚠️ No flat ID found, skipping socket connection');
      }
    });
  }

  /// Show visitor request dialog
  void _showVisitorRequestDialog(Map<String, dynamic> visitorData) {
    final visitorName = visitorData['visitor_name'] ?? 'Unknown';
    final purpose = visitorData['purpose'] ?? 'visit';
    final flatNumber = visitorData['flat_number'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person_add,
                color: AppTheme.accentBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'New Visitor Request',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$visitorName wants to visit',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Purpose: ${purpose.toUpperCase()}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            if (flatNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Flat: $flatNumber',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.warningAmber.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.warningAmber,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Please respond within 5 minutes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warningAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Call API to deny visitor
            },
            child: const Text(
              'Deny',
              style: TextStyle(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Call API to approve visitor
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Approve',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Disconnect socket when leaving home screen
    final socketService = ref.read(socketServiceProvider);
    socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: const Color(0xFFE8ECF4),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primaryOrange,
          unselectedItemColor: const Color(0xFF9CA3AF),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home, size: 24),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.people_outline, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.people, size: 24),
              ),
              label: 'Visitors',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person_outline, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person, size: 24),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTabScreen extends ConsumerWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    final flatNumber = storage.flatNumber ?? 'N/A';
    final blockName = storage.blockName ?? 'N/A';
    final societyName = storage.societyName ?? 'Society360';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFFE8ECF4),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome Home',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1D1F),
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentCyan.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: AppTheme.accentCyan,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$flatNumber, Block $blockName',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.accentCyan,
                                            letterSpacing: 0.1,
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
                        Stack(
                          children: [
                            InkWell(
                              onTap: () => _showNotificationsBottomSheet(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F5F7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: Color(0xFF1A1D1F),
                                  size: 22,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.errorRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms),
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Pending Visitor Approvals Card (moved before Quick Actions)
                  _buildPendingApprovalsCard(context, ref).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActions(context).animate().fadeIn(delay: 250.ms),
                  const SizedBox(height: 24),

                  // Today's Visitors Status
                  _buildTodayVisitorsCard().animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 24),

                  // Recent Activity
                  _buildRecentActivityCard().animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 24),

                  // Society Info
                  _buildSocietyInfoCard(societyName).animate().fadeIn(delay: 500.ms),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {
        'icon': Icons.qr_code_scanner,
        'label': 'Guest Pass',
        'subtitle': 'Create QR code',
        'color': AppTheme.accentBlue,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateGuestPassScreen()),
          );
        },
      },
      {
        'icon': Icons.groups,
        'label': 'Visitors',
        'subtitle': 'Manage guests',
        'color': AppTheme.accentCyan,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyVisitorsScreen()),
          );
        },
      },
      {
        'icon': Icons.phone_in_talk,
        'label': 'Emergency',
        'subtitle': 'Quick contacts',
        'color': AppTheme.errorRed,
        'onTap': () {
          // TODO: Navigate to emergency contacts
        },
      },
      {
        'icon': Icons.campaign,
        'label': 'Notices',
        'subtitle': 'Society updates',
        'color': AppTheme.warningAmber,
        'onTap': () {
          // TODO: Navigate to notices
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1D1F),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return InkWell(
              onTap: action['onTap'] as VoidCallback?,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE8ECF4),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (action['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        action['icon'] as IconData,
                        color: action['color'] as Color,
                        size: 24,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action['label'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1D1F),
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          action['subtitle'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6F767E),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTodayVisitorsCard() {
    // Mock data - in real app, fetch from API
    final visitors = [
      {'name': 'Delivery - Amazon', 'time': '10:30 AM', 'status': 'Approved'},
      {'name': 'Guest - Raj Kumar', 'time': '02:15 PM', 'status': 'Pending'},
      {'name': 'Plumber - Kumar', 'time': '04:00 PM', 'status': 'Expected'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Visitors",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1D1F),
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 14, color: AppTheme.accentBlue),
                  const SizedBox(width: 4),
                  Text(
                    '${visitors.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentBlue,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE8ECF4),
              width: 1,
            ),
          ),
          child: Column(
            children: visitors.asMap().entries.map((entry) {
              final visitor = entry.value;
              final isLast = entry.key == visitors.length - 1;

              Color statusColor;
              switch (visitor['status']) {
                case 'Approved':
                  statusColor = AppTheme.successGreen;
                  break;
                case 'Pending':
                  statusColor = AppTheme.warningAmber;
                  break;
                default:
                  statusColor = AppTheme.accentBlue;
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F5F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person,
                          color: const Color(0xFF6F767E),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visitor['name'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1D1F),
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              visitor['time'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6F767E),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          visitor['status'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE8ECF4), height: 1),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard() {
    final activities = [
      {
        'icon': Icons.check_circle,
        'color': AppTheme.successGreen,
        'title': 'Visitor Approved',
        'subtitle': 'Amazon delivery at gate',
        'time': '2h ago'
      },
      {
        'icon': Icons.qr_code,
        'color': AppTheme.accentBlue,
        'title': 'Guest Pass Created',
        'subtitle': 'Valid for 24 hours',
        'time': '5h ago'
      },
      {
        'icon': Icons.campaign,
        'color': AppTheme.warningAmber,
        'title': 'Society Notice',
        'subtitle': 'Water supply timing changed',
        'time': '1d ago'
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1D1F),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE8ECF4),
              width: 1,
            ),
          ),
          child: Column(
            children: activities.asMap().entries.map((entry) {
              final activity = entry.value;
              final isLast = entry.key == activities.length - 1;

              return Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (activity['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          activity['icon'] as IconData,
                          color: activity['color'] as Color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity['title'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1D1F),
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              activity['subtitle'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6F767E),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        activity['time'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9CA3AF),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE8ECF4), height: 1),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSocietyInfoCard(String societyName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8ECF4),
          width: 1,
        ),
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
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryOrange.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.apartment,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      societyName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D1F),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Society Information',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6F767E),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE8ECF4), height: 1),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.security, 'Guard on duty', '24/7'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.local_parking, 'Parking spots', '2 per flat'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.wifi, 'Community WiFi', 'Available'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.accentCyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.accentCyan),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6F767E),
              letterSpacing: 0.1,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D1F),
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECF4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryOrange.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1D1F),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Notifications list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildNotificationItem(
                    icon: Icons.person_add,
                    iconColor: AppTheme.successGreen,
                    title: 'Visitor Approved',
                    message: 'Your guest Raj Kumar has been approved for entry',
                    time: '10 min ago',
                    isUnread: true,
                  ),
                  _buildNotificationItem(
                    icon: Icons.local_shipping,
                    iconColor: AppTheme.accentCyan,
                    title: 'Delivery Arrived',
                    message: 'Amazon delivery has arrived at the gate',
                    time: '1h ago',
                    isUnread: true,
                  ),
                  _buildNotificationItem(
                    icon: Icons.campaign,
                    iconColor: AppTheme.warningAmber,
                    title: 'Society Notice',
                    message: 'Water supply will be interrupted tomorrow from 10 AM to 2 PM',
                    time: '2h ago',
                    isUnread: false,
                  ),
                  _buildNotificationItem(
                    icon: Icons.event,
                    iconColor: AppTheme.accentBlue,
                    title: 'Upcoming Event',
                    message: 'Society Annual Day on 30th December',
                    time: '1d ago',
                    isUnread: false,
                  ),
                  _buildNotificationItem(
                    icon: Icons.payment,
                    iconColor: AppTheme.errorRed,
                    title: 'Payment Reminder',
                    message: 'Monthly maintenance due in 3 days',
                    time: '2d ago',
                    isUnread: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String time,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? AppTheme.primaryOrange.withOpacity(0.3) : const Color(0xFFE8ECF4),
          width: isUnread ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                  color: const Color(0xFF1A1D1F),
                  letterSpacing: -0.1,
                ),
              ),
            ),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryOrange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6F767E),
                height: 1.4,
                letterSpacing: 0.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              time,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApprovalsCard(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingVisitorsCountProvider);

    // Don't show the card if there are no pending approvals
    if (pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const VisitorApprovalsScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.warningAmber.withOpacity(0.1),
              AppTheme.primaryOrange.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.warningAmber.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.warningAmber.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.warningAmber,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warningAmber.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_add_alt_1,
                color: Colors.white,
                size: 28,
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(),
                )
                .shimmer(
                  duration: 2000.ms,
                  color: Colors.white.withOpacity(0.3),
                )
                .shake(
                  duration: 1500.ms,
                  delay: 500.ms,
                  hz: 2,
                ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending Approvals',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1D1F),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$pendingCount visitor${pendingCount > 1 ? 's' : ''} waiting for approval',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6F767E),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.warningAmber,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$pendingCount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(),
                )
                .scale(
                  duration: 1000.ms,
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.15, 1.15),
                  curve: Curves.easeInOut,
                )
                .then()
                .scale(
                  duration: 1000.ms,
                  begin: const Offset(1.15, 1.15),
                  end: const Offset(1.0, 1.0),
                  curve: Curves.easeInOut,
                ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Color(0xFF6F767E),
            ),
          ],
        ),
      ),
    );
  }
}
