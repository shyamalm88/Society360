import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'core/storage/storage_service.dart';
import 'core/fcm/fcm_service.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/visitor_approvals/presentation/visitor_approvals_screen.dart';
import 'data/repositories/visitor_repository.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register FCM background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for LIGHT theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundLight,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        // Provide SharedPreferences instance
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const Society360ResidentApp(),
    ),
  );
}

class Society360ResidentApp extends ConsumerStatefulWidget {
  const Society360ResidentApp({super.key});

  @override
  ConsumerState<Society360ResidentApp> createState() => _Society360ResidentAppState();
}

class _Society360ResidentAppState extends ConsumerState<Society360ResidentApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Initialize FCM after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFCM();
    });
  }

  Future<void> _initializeFCM() async {
    try {
      final fcmService = ref.read(fcmServiceProvider);

      // Set up foreground message handler
      fcmService.onForegroundMessage = (message) {
        debugPrint('📬 Foreground message received: ${message.notification?.title}');

        // Immediately refresh pending visitors list (with error handling)
        try {
          ref.invalidate(pendingVisitorsProvider);
          debugPrint('🔄 Pending visitors list refreshed');
        } catch (e) {
          debugPrint('⚠️ Error refreshing pending visitors: $e');
        }
      };

      // Set up notification tap handler
      fcmService.onNotificationTap = (data) {
        debugPrint('🔔 Notification tapped with data: $data');
        _handleNotificationNavigation(data);
      };

      // Initialize FCM service
      await fcmService.initialize();

      debugPrint('✅ FCM initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing FCM: $e');
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    final screen = data['screen'];

    debugPrint('📍 Navigating to: type=$type, screen=$screen');

    // Use navigatorKey to navigate from anywhere in the app
    if (screen == 'visitor_approvals' || type == 'visitor_request') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const VisitorApprovalsScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Society360 Resident',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // Using LIGHT theme
      home: const SplashScreen(),
    );
  }
}
