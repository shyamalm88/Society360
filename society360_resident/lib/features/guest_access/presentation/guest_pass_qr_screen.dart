import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../config/theme.dart';

class GuestPassQrScreen extends StatelessWidget {
  final String guestName;
  final String guestPhone;
  final String purpose;
  final DateTime validFrom;
  final DateTime validUntil;
  final String qrCode;
  final String accessCode;

  // GlobalKey for capturing QR code as image
  final GlobalKey _qrKey = GlobalKey();

  GuestPassQrScreen({
    super.key,
    required this.guestName,
    required this.guestPhone,
    required this.purpose,
    required this.validFrom,
    required this.validUntil,
    required this.qrCode,
    required this.accessCode,
  });

  Future<void> _shareGuestPass() async {
    try {
      final validFromFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(validFrom);
      final validUntilFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(validUntil);

      // Capture QR code as image
      final RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/guest_pass_qr.png');
      await file.writeAsBytes(pngBytes);

      final message = '''
🎫 Society360 Guest Pass

ACCESS CODE: $accessCode

Guest Name: $guestName
Phone: $guestPhone
Purpose: $purpose

Valid From: $validFromFormatted
Valid Until: $validUntilFormatted

Show this QR code at the gate or share the access code with the guard.

Powered by Society360
    ''';

      // Share image with message
      await Share.shareXFiles(
        [XFile(file.path)],
        text: message,
        subject: 'Guest Pass for $guestName',
      );
    } catch (e) {
      debugPrint('❌ Error sharing guest pass: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guest Pass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareGuestPass,
            tooltip: 'Share Guest Pass',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success Message
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 36,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Guest Pass Created!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share this QR code with your guest',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // QR Code Card
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // QR Code with RepaintBoundary for capturing as image
                  RepaintBoundary(
                    key: _qrKey,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: qrCode,
                        version: QrVersions.auto,
                        size: 250,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        embeddedImage: const AssetImage('assets/logo.png'),
                        embeddedImageStyle: const QrEmbeddedImageStyle(
                          size: Size(40, 40),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Access Code Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryOrange.withOpacity(0.1),
                          AppTheme.accentBlue.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryOrange.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Access Code',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          accessCode,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryOrange,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Share this code with guard',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Guest Details
                  _buildDetailRow(
                    icon: Icons.person,
                    label: 'Guest Name',
                    value: guestName,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.phone,
                    label: 'Phone',
                    value: guestPhone,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.category,
                    label: 'Purpose',
                    value: purpose,
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: AppTheme.surfaceBorder),
                  const SizedBox(height: 20),

                  // Validity Period
                  Row(
                    children: [
                      Expanded(
                        child: _buildValidityCard(
                          label: 'Valid From',
                          dateTime: validFrom,
                          color: AppTheme.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildValidityCard(
                          label: 'Valid Until',
                          dateTime: validUntil,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Column(
              children: [
                // Share Button - Primary Action
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _shareGuestPass,
                    icon: const Icon(Icons.share),
                    label: const Text('Share Guest Pass'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Go Home Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Go to Home'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Instructions
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Instructions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• Share this QR code with your guest\n'
                    '• Guest should show this at the gate\n'
                    '• Valid only during specified time period\n'
                    '• One-time use QR code',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.6,
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.accentBlue),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValidityCard({
    required String label,
    required DateTime dateTime,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('dd MMM').format(dateTime),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            DateFormat('hh:mm a').format(dateTime),
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
