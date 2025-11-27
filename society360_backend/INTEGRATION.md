# Flutter Integration Guide

Complete guide to integrate the Guard and Resident Flutter apps with the Node.js backend.

## Prerequisites

1. Backend server running on `http://localhost:3000` (or your production URL)
2. Firebase project configured for both apps
3. PostgreSQL database with sample data

## Common Setup for Both Apps

### 1. Add Dependencies to `pubspec.yaml`

```yaml
dependencies:
  dio: ^5.4.0
  socket_io_client: ^2.0.3+1
  flutter_secure_storage: ^9.0.0
```

### 2. Create API Service Base Class

Create `lib/data/services/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:3000/v1'; // Change for production

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add interceptor for auth token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Get Firebase ID token
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Handle token expiry
        if (error.response?.statusCode == 401) {
          // Token expired, refresh it
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await user.getIdToken(true); // Force refresh
            // Retry the request
            return handler.resolve(await _retry(error.requestOptions));
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  Dio get dio => _dio;
}
```

### 3. Create Socket.io Service

Create `lib/data/services/socket_service.dart`:

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService {
  static const String socketUrl = 'http://localhost:3000'; // Change for production

  late IO.Socket socket;
  bool _connected = false;

  bool get isConnected => _connected;

  void connect() {
    socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build(),
    );

    socket.onConnect((_) {
      debugPrint('✅ Socket.io connected: ${socket.id}');
      _connected = true;
    });

    socket.onDisconnect((_) {
      debugPrint('❌ Socket.io disconnected');
      _connected = false;
    });

    socket.onError((error) {
      debugPrint('Socket.io error: $error');
    });

    socket.connect();
  }

  void joinRoom(String roomType, String roomId, String userId) {
    if (!_connected) {
      debugPrint('⚠️  Socket not connected, cannot join room');
      return;
    }

    socket.emit('join_room', {
      'room_type': roomType,
      'room_id': roomId,
      'user_id': userId,
    });

    debugPrint('Joined room: $roomType:$roomId');
  }

  void leaveRoom(String roomType, String roomId) {
    socket.emit('leave_room', {
      'room_type': roomType,
      'room_id': roomId,
    });
  }

  void disconnect() {
    socket.disconnect();
    _connected = false;
  }
}
```

---

## Guard App Integration

### 1. Update Auth Repository

Modify `lib/core/auth/auth_repository.dart`:

```dart
import 'package:dio/dio.dart';
import '../data/services/api_client.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> loginWithPin(String pin) async {
    // For Guard app, PIN is hardcoded validation
    if (pin == '123456') {
      // In production, exchange PIN for a session token via API
      // For now, we'll use a mock token
      await _storage.write(key: 'session_token', value: 'mock_guard_token');
      return {'success': true};
    }
    throw Exception('Invalid PIN');
  }
}
```

### 2. Create Visitor API Service

Create `lib/data/services/visitor_api_service.dart`:

```dart
import 'package:dio/dio.dart';
import 'api_client.dart';

class VisitorApiService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> createVisitor({
    required String visitorName,
    required String phone,
    required String flatId,
    required String purpose,
    String? vehicleNo,
    String? idType,
    String? idNumber,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/visitors',
        data: {
          'visitor_name': visitorName,
          'phone': phone,
          'flat_id': flatId,
          'purpose': purpose,
          'vehicle_no': vehicleNo,
          'id_type': idType,
          'id_number': idNumber,
          'expected_start': DateTime.now().toIso8601String(),
          'idempotency_key': 'guard_${DateTime.now().millisecondsSinceEpoch}',
        },
      );

      return response.data;
    } on DioException catch (e) {
      throw Exception('Failed to create visitor: ${e.message}');
    }
  }

  Future<List<dynamic>> getRecentVisitors(String societyId) async {
    try {
      final response = await _apiClient.dio.get(
        '/society/$societyId/expected-visitors',
        queryParameters: {
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );

      return response.data['data'] as List<dynamic>;
    } on DioException catch (e) {
      throw Exception('Failed to fetch visitors: ${e.message}');
    }
  }
}
```

### 3. Update Visitor Form Controller

Modify `lib/features/visitor/presentation/visitor_form_controller.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/services/visitor_api_service.dart';

@riverpod
class VisitorFormController extends _$VisitorFormController {
  final VisitorApiService _apiService = VisitorApiService();

  @override
  VisitorFormState build() {
    return VisitorFormState.initial();
  }

  Future<void> submitVisitor() async {
    final formData = state;

    try {
      // Call real API instead of console.log
      final result = await _apiService.createVisitor(
        visitorName: formData.name,
        phone: formData.phone,
        flatId: formData.selectedFlatId!,
        purpose: formData.purpose,
        vehicleNo: formData.vehicleNo,
      );

      print('✅ Visitor created: ${result['data']['visitor']['id']}');

      // Reset form
      state = VisitorFormState.initial();
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }
}
```

### 4. Listen to Socket Events (Guard Dashboard)

Modify `lib/features/dashboard/presentation/dashboard_screen.dart`:

```dart
import '../../../data/services/socket_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _initializeSocket();
  }

  void _initializeSocket() {
    _socketService.connect();

    // Join society room (replace with actual society ID)
    final societyId = 'YOUR_SOCIETY_ID'; // Get from user profile
    _socketService.joinRoom('society', societyId, 'guard_user_id');

    // Listen for approval events
    _socketService.socket.on('request_approved', (data) {
      print('🔔 Visitor approved: ${data['visitor_name']}');

      // Show notification or update UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Visitor ${data['visitor_name']} ${data['decision']}'),
          backgroundColor: data['decision'] == 'accept' ? Colors.green : Colors.red,
        ),
      );
    });
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }

  // ... rest of widget
}
```

---

## Resident App Integration

### 1. Update Auth Service

Modify `lib/core/auth/auth_service.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/api_client.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> exchangeFirebaseToken() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No Firebase user');

    final idToken = await user.getIdToken();

    final response = await _apiClient.dio.post(
      '/auth/firebase',
      data: {'idToken': idToken},
    );

    return response.data['data'];
  }
}
```

### 2. Update Metadata Repository

Modify `lib/data/repositories/metadata_repository.dart`:

```dart
import 'package:dio/dio.dart';
import '../services/api_client.dart';

class MetadataRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<String>> getCities() async {
    final response = await _apiClient.dio.get('/cities');
    return List<String>.from(response.data['data']);
  }

  Future<List<Map<String, dynamic>>> getSocieties(String city) async {
    final response = await _apiClient.dio.get(
      '/societies',
      queryParameters: {'city': city},
    );
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<List<Map<String, dynamic>>> getComplexes(String societyId) async {
    final response = await _apiClient.dio.get(
      '/complexes',
      queryParameters: {'society_id': societyId},
    );
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<List<Map<String, dynamic>>> getBlocks(String complexId) async {
    final response = await _apiClient.dio.get(
      '/blocks',
      queryParameters: {'complex_id': complexId},
    );
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<List<Map<String, dynamic>>> getFlats(String blockId) async {
    final response = await _apiClient.dio.get(
      '/flats',
      queryParameters: {'block_id': blockId},
    );
    return List<Map<String, dynamic>>.from(response.data['data']);
  }
}
```

### 3. Add Socket Listener (Home Screen)

Modify `lib/features/home/presentation/home_screen.dart`:

```dart
import '../../../data/services/socket_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final SocketService _socketService = SocketService();
  Map<String, dynamic>? _pendingVisitor;

  @override
  void initState() {
    super.initState();
    _initializeSocket();
  }

  void _initializeSocket() {
    _socketService.connect();

    // Get flat ID from storage or state
    final flatId = 'USER_FLAT_ID'; // Get from user profile/storage
    final userId = 'USER_ID';

    // Join flat room
    _socketService.joinRoom('flat', flatId, userId);

    // Listen for visitor requests
    _socketService.socket.on('visitor_request', (data) {
      print('🔔 New visitor at gate: ${data['visitor_name']}');

      setState(() {
        _pendingVisitor = data;
      });

      // Show bottom sheet or dialog
      _showVisitorApprovalDialog(data);
    });
  }

  void _showVisitorApprovalDialog(Map<String, dynamic> visitorData) {
    showModalBottomSheet(
      context: context,
      builder: (context) => VisitorApprovalSheet(
        visitorData: visitorData,
        onApprove: () => _respondToVisitor(visitorData['visitor_id'], 'accept'),
        onDeny: () => _respondToVisitor(visitorData['visitor_id'], 'deny'),
      ),
    );
  }

  Future<void> _respondToVisitor(String visitorId, String decision) async {
    try {
      final apiClient = ApiClient();
      await apiClient.dio.post(
        '/visitors/$visitorId/respond',
        data: {
          'decision': decision,
          'note': decision == 'accept' ? 'Approved' : 'Denied',
        },
      );

      setState(() {
        _pendingVisitor = null;
      });

      Navigator.pop(context);
    } catch (e) {
      print('Error responding to visitor: $e');
    }
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }

  // ... rest of widget
}
```

### 4. Submit Resident Request (Onboarding)

Add to onboarding screen after flat selection:

```dart
Future<void> submitResidentRequest(String flatId) async {
  try {
    final apiClient = ApiClient();
    final response = await apiClient.dio.post(
      '/resident-requests',
      data: {
        'flat_id': flatId,
        'requested_role': 'tenant', // or 'owner'
        'note': 'Requesting access',
      },
    );

    print('Resident request submitted: ${response.data['data']['id']}');

    // Navigate to home or pending approval screen
  } catch (e) {
    print('Error submitting request: $e');
  }
}
```

---

## Testing the Integration

### 1. Start Backend
```bash
cd society360_backend
npm run dev
```

### 2. Seed Sample Data

Run this SQL to create test data:

```sql
-- Insert test society
INSERT INTO societies (id, name, city) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Green Acres', 'Bengaluru');

-- Insert complex
INSERT INTO complexes (id, society_id, name) VALUES
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Tower A');

-- Insert block
INSERT INTO blocks (id, complex_id, name) VALUES
  ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'Block A');

-- Insert flats
INSERT INTO flats (id, block_id, flat_number) VALUES
  ('44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', '101');
```

### 3. Test Flow

1. **Resident App:** Login with Firebase Phone Auth
2. **Resident App:** Complete onboarding (select City → Society → Complex → Block → Flat)
3. **Guard App:** Login with PIN (123456)
4. **Guard App:** Create new visitor for Flat 101
5. **Resident App:** Receive real-time notification via Socket.io
6. **Resident App:** Approve visitor
7. **Guard App:** Receive approval confirmation via Socket.io
8. **Guard App:** Check in visitor

---

## Production Deployment

### Update API Base URLs:

**api_client.dart:**
```dart
static const String baseUrl = 'https://api.society360.com/v1';
```

**socket_service.dart:**
```dart
static const String socketUrl = 'https://api.society360.com';
```

### Environment Variables:

Use `flutter_dotenv` to manage environments:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

static final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/v1';
```

---

**Integration complete! Your Flutter apps are now connected to the real backend with Socket.io real-time events.**
