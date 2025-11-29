import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';

/// QR Scanner Screen for Guest Pass
/// Scans QR codes and fetches visitor details from backend
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isProcessing = false;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Stop scanner when app goes to background
    if (state == AppLifecycleState.paused) {
      _scannerController.stop();
    }
    // Restart scanner when app comes to foreground (only if not already scanned)
    else if (state == AppLifecycleState.resumed && !_hasScanned) {
      _scannerController.start();
    }
  }

  Future<void> _fetchVisitorByAccessCode(String accessCode) async {
    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    // Stop scanner if running
    await _scannerController.stop();

    try {
      // Fetch visitor details from backend using access code
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/visitors/by-access-code/$accessCode');

      debugPrint('✅ Visitor details fetched by access code: ${response.data}');

      if (mounted && response.data['success'] == true) {
        final visitorData = response.data['data'];

        // Navigate to visitor details screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GuestPassDetailsScreen(
              visitorData: visitorData,
            ),
          ),
        );
      } else {
        throw Exception(response.data['error'] ?? 'Failed to fetch visitor details');
      }
    } catch (e) {
      debugPrint('❌ Error fetching visitor by access code: $e');

      if (mounted) {
        // Show error and allow retry
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('$e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isProcessing = false;
                    _hasScanned = false;
                  });
                  _scannerController.start();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showManualEntryDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Access Code'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Access Code',
            hintText: 'Enter 6-digit code',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim().toUpperCase();
              if (code.length == 6) {
                Navigator.of(context).pop();
                _fetchVisitorByAccessCode(code);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _onQrCodeDetected(BarcodeCapture barcodeCapture) async {
    if (_isProcessing || _hasScanned) return;

    final barcode = barcodeCapture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final qrCode = barcode!.rawValue!;
    debugPrint('📷 QR Code scanned: $qrCode');

    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    // Stop scanner
    await _scannerController.stop();

    try {
      // Fetch visitor details from backend
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/visitors/by-qr/$qrCode');

      debugPrint('✅ Visitor details fetched: ${response.data}');

      if (mounted && response.data['success'] == true) {
        final visitorData = response.data['data'];

        // Navigate to visitor details screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GuestPassDetailsScreen(
              visitorData: visitorData,
            ),
          ),
        );
      } else {
        throw Exception(response.data['error'] ?? 'Failed to fetch visitor details');
      }
    } catch (e) {
      debugPrint('❌ Error fetching visitor details: $e');

      if (mounted) {
        // Show error and allow retry
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('$e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to previous screen
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isProcessing = false;
                    _hasScanned = false;
                  });
                  _scannerController.start();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan Guest Pass',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard, color: Colors.white),
            tooltip: 'Enter access code manually',
            onPressed: _showManualEntryDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onQrCodeDetected,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 64,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Camera Not Available',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'The camera is not supported on this device.\n\nQR code scanning requires a physical device with a camera. Please test on a real device.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Overlay with cutout
          CustomPaint(
            painter: ScannerOverlayPainter(),
            child: Container(),
          ),

          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Point camera at QR code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_isProcessing) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ],
              ],
            ),
          ),

          // Toggle flash button
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(
                  Icons.flash_on,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () => _scannerController.toggleTorch(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for scanner overlay
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final cutoutSize = size.width * 0.7;
    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cutoutSize,
      height: cutoutSize,
    );

    // Draw overlay with cutout
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16))),
      ),
      paint,
    );

    // Draw corner brackets
    final cornerPaint = Paint()
      ..color = AppTheme.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const cornerLength = 30.0;

    // Top-left
    canvas.drawLine(
      Offset(cutoutRect.left, cutoutRect.top + cornerLength),
      Offset(cutoutRect.left, cutoutRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutoutRect.left, cutoutRect.top),
      Offset(cutoutRect.left + cornerLength, cutoutRect.top),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(cutoutRect.right - cornerLength, cutoutRect.top),
      Offset(cutoutRect.right, cutoutRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutoutRect.right, cutoutRect.top),
      Offset(cutoutRect.right, cutoutRect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(cutoutRect.left, cutoutRect.bottom - cornerLength),
      Offset(cutoutRect.left, cutoutRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutoutRect.left, cutoutRect.bottom),
      Offset(cutoutRect.left + cornerLength, cutoutRect.bottom),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(cutoutRect.right - cornerLength, cutoutRect.bottom),
      Offset(cutoutRect.right, cutoutRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutoutRect.right, cutoutRect.bottom - cornerLength),
      Offset(cutoutRect.right, cutoutRect.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Guest Pass Details Screen
/// Shows visitor information after QR scan and allows check-in
class GuestPassDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> visitorData;

  const GuestPassDetailsScreen({
    super.key,
    required this.visitorData,
  });

  @override
  ConsumerState<GuestPassDetailsScreen> createState() => _GuestPassDetailsScreenState();
}

class _GuestPassDetailsScreenState extends ConsumerState<GuestPassDetailsScreen> {
  bool _isCheckingIn = false;

  Future<void> _approveAndCheckIn() async {
    setState(() => _isCheckingIn = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final visitorId = widget.visitorData['id'];

      debugPrint('✅ Approving guest pass: $visitorId');

      // Step 1: Approve the visitor
      final approveResponse = await apiClient.post(
        '/visitors/$visitorId/guard-respond',
        data: {
          'decision': 'accept',
          'note': 'Guest pass verified at gate',
        },
      );

      debugPrint('✅ Approval response: ${approveResponse.data}');

      if (approveResponse.data['success'] != true) {
        throw Exception(approveResponse.data['error'] ?? 'Failed to approve visitor');
      }

      // Step 2: Check in the visitor
      debugPrint('🚪 Checking in visitor: $visitorId');

      final checkInResponse = await apiClient.post(
        '/visits/checkin',
        data: {
          'visitor_id': visitorId,
        },
      );

      debugPrint('✅ Check-in response: ${checkInResponse.data}');

      if (mounted && checkInResponse.data['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Guest approved and checked in successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );

        // Go back to home
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        throw Exception(checkInResponse.data['error'] ?? 'Failed to check in');
      }
    } catch (e) {
      debugPrint('❌ Error approving/checking in: $e');

      if (mounted) {
        setState(() => _isCheckingIn = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve/check in: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkIn() async {
    setState(() => _isCheckingIn = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final visitorId = widget.visitorData['id'];

      debugPrint('🚪 Checking in visitor: $visitorId');

      final response = await apiClient.post(
        '/visits/checkin',
        data: {
          'visitor_id': visitorId,
        },
      );

      debugPrint('✅ Check-in response: ${response.data}');

      if (mounted && response.data['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Guest checked in successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );

        // Go back to home
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        throw Exception(response.data['error'] ?? 'Failed to check in');
      }
    } catch (e) {
      debugPrint('❌ Error checking in: $e');

      if (mounted) {
        setState(() => _isCheckingIn = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check in: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitorName = widget.visitorData['visitor_name'] ?? 'Unknown';
    final phone = widget.visitorData['phone'] ?? 'N/A';
    final purpose = widget.visitorData['purpose'] ?? 'N/A';
    final numberOfPeople = widget.visitorData['number_of_people'] ?? 1;
    final flatNumber = widget.visitorData['flat_number'] ?? 'N/A';
    final blockName = widget.visitorData['block_name'] ?? 'N/A';
    final invitedByName = widget.visitorData['invited_by_name'] ?? 'N/A';
    final invitedByPhone = widget.visitorData['invited_by_phone'] ?? '';
    final expectedStart = widget.visitorData['expected_start'];
    final expectedEnd = widget.visitorData['expected_end'];
    final status = widget.visitorData['status'] ?? 'pending';
    final visitId = widget.visitorData['visit_id'];

    // Check if already checked in
    final isAlreadyCheckedIn = visitId != null;

    // Format dates
    String validityText = 'N/A';
    if (expectedStart != null) {
      final startDate = DateTime.parse(expectedStart);
      final endDate = expectedEnd != null ? DateTime.parse(expectedEnd) : null;

      if (endDate != null) {
        validityText = '${DateFormat('MMM dd, hh:mm a').format(startDate)} - ${DateFormat('MMM dd, hh:mm a').format(endDate)}';
      } else {
        validityText = 'From ${DateFormat('MMM dd, yyyy · hh:mm a').format(startDate)}';
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Guest Pass Details',
          style: TextStyle(
            color: Color(0xFF1A1D1F),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1D1F)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: status == 'accepted'
                    ? AppTheme.successGreen.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == 'accepted' ? Icons.verified : Icons.pending,
                    size: 18,
                    color: status == 'accepted' ? AppTheme.successGreen : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status == 'accepted' ? 'PRE-APPROVED' : status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: status == 'accepted' ? AppTheme.successGreen : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Visitor Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                children: [
                  // Visitor Name
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppTheme.primaryBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Guest Name',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6F767E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              visitorName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1D1F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // Phone
                  _buildInfoRow(Icons.phone, 'Phone Number', phone),
                  const SizedBox(height: 16),

                  // Purpose
                  _buildInfoRow(Icons.category, 'Purpose', purpose),
                  const SizedBox(height: 16),

                  // Number of People
                  _buildInfoRow(Icons.people, 'Number of People', '$numberOfPeople'),
                  const SizedBox(height: 16),

                  // Visiting
                  _buildInfoRow(Icons.home, 'Visiting', 'Flat $flatNumber · Block $blockName'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Resident Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                children: [
                  const Text(
                    'Invited By',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D1F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.person_outline, 'Name', invitedByName),
                  if (invitedByPhone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.phone_outlined, 'Phone', invitedByPhone),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Validity Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                children: [
                  const Text(
                    'Validity Period',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D1F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.calendar_today, 'Valid Period', validityText),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Check-in Button
            if (!isAlreadyCheckedIn)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isCheckingIn
                      ? null
                      : (status == 'pending' ? _approveAndCheckIn : _checkIn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'pending'
                        ? AppTheme.primaryOrange
                        : AppTheme.successGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isCheckingIn
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              status == 'pending' ? Icons.verified_user : Icons.check_circle,
                              size: 24
                            ),
                            const SizedBox(width: 8),
                            Text(
                              status == 'pending'
                                  ? 'Approve & Check In'
                                  : 'Check In Guest',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.successGreen,
                    width: 2,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.successGreen, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Already Checked In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6F767E)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6F767E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1D1F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
