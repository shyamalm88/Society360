import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'dart:io' show Platform;
import '../api/api_client.dart';

/// FCM Service for Guard App
/// Handles Firebase Cloud Messaging for visitor approval notifications
class FCMService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiClient? _apiClient;

  /// Callback for handling notification taps
  Function(Map<String, dynamic>)? onNotificationTap;

  FCMService({ApiClient? apiClient}) : _apiClient = apiClient;

  /// Initialize FCM service
  Future<void> initialize() async {
    try {
      // Request permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ FCM permission granted');

        // Initialize local notifications
        const androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosSettings = DarwinInitializationSettings();

        await _localNotifications.initialize(
          const InitializationSettings(
            android: androidSettings,
            iOS: iosSettings,
          ),
          onDidReceiveNotificationResponse: _onNotificationTapHandler,
        );

        // Get FCM token
        String? token = await _fcm.getToken();
        if (token != null) {
          debugPrint('📱 FCM Token: $token');
          // TODO: Register token with backend
          // await _registerTokenWithBackend(token);
        }

        // Listen for token refresh
        _fcm.onTokenRefresh.listen((newToken) {
          debugPrint('🔄 FCM Token refreshed: $newToken');
          // TODO: Update token on backend
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background/terminated message taps
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Check if app was opened from terminated state by notification
        RemoteMessage? initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        debugPrint('✅ FCM Service initialized');
      } else {
        debugPrint('❌ FCM permission denied');
      }
    } catch (e) {
      debugPrint('❌ FCM initialization error: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification != null) {
      _showLocalNotification(
        notification.title ?? 'Notification',
        notification.body ?? '',
        message.data,
      );
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.data}');

    if (onNotificationTap != null) {
      onNotificationTap!(message.data);
    }

    // Navigate based on notification type
    final type = message.data['type'];
    switch (type) {
      case 'visitor_approval':
        // Navigate to approvals screen
        debugPrint('Navigate to visitor approvals screen');
        break;
      case 'visitor_timeout':
        // Navigate to approvals screen
        debugPrint('Navigate to visitor approvals screen');
        break;
      default:
        debugPrint('Unknown notification type: $type');
    }
  }

  /// Handle local notification tap
  void _onNotificationTapHandler(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.payload}');
    // Parse payload and navigate
  }

  /// Show local notification
  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'society360_guard_channel',
        'Society360 Guard Notifications',
        channelDescription: 'Visitor approval and check-in notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: data.toString(),
      );

      debugPrint('✅ Local notification shown');
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

  /// Register FCM token with backend
  Future<void> registerToken() async {
    try {
      if (_apiClient == null) {
        debugPrint('⚠️  ApiClient not provided, skipping FCM token registration');
        return;
      }

      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint('🔑 Registering FCM token with backend...');

        // Determine device type
        String deviceType = 'android';
        if (!kIsWeb) {
          if (Platform.isIOS) {
            deviceType = 'ios';
          } else if (Platform.isAndroid) {
            deviceType = 'android';
          }
        } else {
          deviceType = 'web';
        }

        final response = await _apiClient!.post(
          '/fcm-token',
          data: {
            'token': token,
            'device_type': deviceType,
            'device_info': {
              'platform': deviceType,
              'is_web': kIsWeb,
            },
          },
        );

        final responseData = response.data as Map<String, dynamic>;
        if (responseData['success'] == true) {
          debugPrint('✅ FCM token registered successfully');
        } else {
          debugPrint('❌ Failed to register FCM token: ${responseData['error']}');
        }
      } else {
        debugPrint('⚠️  FCM token is null, cannot register');
      }
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
      // Don't rethrow - token registration shouldn't crash the app
    }
  }

  /// Dispose
  void dispose() {
    // Cleanup if needed
  }
}
