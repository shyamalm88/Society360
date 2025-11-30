import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../api/api_client.dart';

/// Background message handler (top-level function required by FCM)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📱 [FCM Background] Message received: ${message.messageId}');
  debugPrint('📱 [FCM Background] Data: ${message.data}');
  debugPrint('📱 [FCM Background] Notification: ${message.notification?.title}');
}

/// Firebase Cloud Messaging Service
/// Handles push notifications for visitor requests
class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiClient _apiClient;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Callback when notification is tapped (for navigation)
  Function(Map<String, dynamic>)? onNotificationTap;

  // Callback when foreground notification received (to show dialog/update UI)
  Function(RemoteMessage)? onForegroundMessage;

  FCMService(this._apiClient);

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        if (response.payload != null) {
          debugPrint('🔔 Local notification tapped: ${response.payload}');
          // Parse payload and navigate
          // The payload will be a JSON string with notification data
        }
      },
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'visitor_requests', // id
        'Visitor Requests', // name
        description: 'Notifications for visitor approval requests',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('✅ Android notification channel created');
    }

    debugPrint('✅ Local notifications initialized');
  }

  /// Initialize FCM service
  /// Call this once during app startup
  Future<void> initialize() async {
    try {
      debugPrint('🔔 Initializing FCM Service...');

      // Initialize local notifications first
      await _initializeLocalNotifications();

      // Request notification permissions
      final settings = await _requestPermissions();

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('⚠️ Notification permissions not granted');
        return;
      }

      debugPrint('✅ Notification permissions granted');

      // Get FCM token
      final token = await getToken();
      if (token != null) {
        debugPrint('📱 FCM Token obtained: ${token.substring(0, 20)}...');
        await _registerTokenWithBackend(token);
      }

      // Set up message handlers
      _setupMessageHandlers();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed');
        _registerTokenWithBackend(newToken);
      });

      debugPrint('✅ FCM Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing FCM: $e');
    }
  }

  /// Request notification permissions
  Future<NotificationSettings> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('📋 Notification permission status: ${settings.authorizationStatus}');
    return settings;
  }

  /// Get FCM token
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      return token;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Register FCM token with backend
  /// Includes retry logic for reliability
  Future<void> _registerTokenWithBackend(String token, {int retryCount = 0}) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    try {
      debugPrint('📤 Registering FCM token with backend (attempt ${retryCount + 1})...');

      final deviceType = Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'web';

      final response = await _apiClient.post(
        '/fcm-token',
        data: {
          'token': token,
          'device_type': deviceType,
          'device_info': {
            'platform': Platform.operatingSystem,
            'version': Platform.operatingSystemVersion,
          },
        },
      );

      if (response.data['success'] == true) {
        debugPrint('✅ FCM token registered with backend');
      } else {
        final error = response.data['error'] ?? 'Unknown error';
        debugPrint('❌ Failed to register FCM token: $error');

        // Retry on failure
        if (retryCount < maxRetries) {
          debugPrint('🔄 Retrying FCM token registration in ${retryDelay.inSeconds}s...');
          await Future.delayed(retryDelay);
          await _registerTokenWithBackend(token, retryCount: retryCount + 1);
        }
      }
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');

      // Retry on error (e.g., network issues, auth not ready)
      if (retryCount < maxRetries) {
        debugPrint('🔄 Retrying FCM token registration in ${retryDelay.inSeconds}s...');
        await Future.delayed(retryDelay);
        await _registerTokenWithBackend(token, retryCount: retryCount + 1);
      } else {
        debugPrint('❌ Max retries reached for FCM token registration');
      }
    }
  }

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Generate unique notification ID based on timestamp to prevent grouping
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Notification details for Android
    const androidDetails = AndroidNotificationDetails(
      'visitor_requests', // channel id
      'Visitor Requests', // channel name
      channelDescription: 'Notifications for visitor approval requests',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      // Don't group notifications - each should make sound
      groupKey: null,
      setAsGroupSummary: false,
      autoCancel: true,
      // Use default notification sound
      enableLights: true,
    );

    // Notification details for iOS
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    // Combined notification details
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show the notification with unique ID
    await _localNotifications.show(
      notificationId, // Use timestamp-based unique ID
      notification.title ?? 'Visitor Request',
      notification.body ?? 'You have a new visitor request',
      notificationDetails,
      payload: message.data.toString(), // Pass data for tap handling
    );

    debugPrint('✅ Local notification displayed with ID: $notificationId');
  }

  /// Setup message handlers for different app states
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 [FCM Foreground] Message received');
      debugPrint('📬 [FCM Foreground] Title: ${message.notification?.title}');
      debugPrint('📬 [FCM Foreground] Body: ${message.notification?.body}');
      debugPrint('📬 [FCM Foreground] Data: ${message.data}');

      // Show local notification in foreground
      _showLocalNotification(message);

      // Call callback to show in-app notification or dialog
      onForegroundMessage?.call(message);
    });

    // Background/Terminated - User taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 [FCM] Notification tapped (background)');
      debugPrint('🔔 [FCM] Data: ${message.data}');

      _handleNotificationTap(message.data);
    });

    // Check if app was opened from terminated state via notification
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('🔔 [FCM] App opened from notification (terminated)');
        debugPrint('🔔 [FCM] Data: ${message.data}');

        _handleNotificationTap(message.data);
      }
    });
  }

  /// Handle notification tap - navigate to appropriate screen
  void _handleNotificationTap(Map<String, dynamic> data) {
    try {
      final type = data['type'];
      final screen = data['screen'];

      debugPrint('🎯 Notification tap: type=$type, screen=$screen');

      // Call the navigation callback
      onNotificationTap?.call(data);
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
    }
  }

  /// Delete FCM token (call on logout)
  Future<void> deleteToken() async {
    try {
      final token = await getToken();
      if (token != null) {
        // Delete from backend
        await _apiClient.delete(
          '/fcm-token',
          data: {'token': token},
        );

        // Delete from Firebase
        await _messaging.deleteToken();

        debugPrint('✅ FCM token deleted');
      }
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }
}

/// Riverpod provider for FCM Service
final fcmServiceProvider = Provider<FCMService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FCMService(apiClient);
});
