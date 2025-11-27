/// Web Push Notification Configuration
class PushConfig {
  // VAPID keys for web push notifications
  static const String vapidPublicKey = 'BFKunk64sJrgvswfeAV_LWgYUjMwd3sBTfroiB5lH-W1Fj7qbFcEMqk-BgBdenZAoFcpzK6Z67JLLkEwQ7lqgoY';

  // Note: Private key should NEVER be stored in client code
  // This is stored here for reference only - it should be kept on the server side
  // Private key: ndxJcm2Wpzx5zRZ5g5XORDlIeOw_zgBnlm-PXTeKpPo

  // Firebase Cloud Messaging configuration
  static const String fcmSenderId = '161086137868';
  static const String projectId = 'society360-b8abe';
}
