import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local Storage Service using SharedPreferences
class StorageService {
  static const String _keyIsFirstLaunch = 'is_first_launch';
  static const String _keyUserId = 'user_id';
  static const String _keyPhoneNumber = 'phone_number';
  static const String _keyFlatId = 'flat_id';
  static const String _keyFlatNumber = 'flat_number';
  static const String _keyBlockName = 'block_name';
  static const String _keySocietyName = 'society_name';
  static const String _keyCityName = 'city_name';
  static const String _keyUserName = 'user_name';
  static const String _keyIsOnboarded = 'is_onboarded';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // First Launch
  bool get isFirstLaunch => _prefs.getBool(_keyIsFirstLaunch) ?? true;
  Future<void> setFirstLaunchComplete() =>
      _prefs.setBool(_keyIsFirstLaunch, false);

  // User ID
  String? get userId => _prefs.getString(_keyUserId);
  Future<void> setUserId(String id) => _prefs.setString(_keyUserId, id);

  // Phone Number
  String? get phoneNumber => _prefs.getString(_keyPhoneNumber);
  Future<void> setPhoneNumber(String phone) =>
      _prefs.setString(_keyPhoneNumber, phone);

  // User Name
  String? get userName => _prefs.getString(_keyUserName);
  Future<void> setUserName(String name) => _prefs.setString(_keyUserName, name);

  // Onboarding Status
  bool get isOnboarded => _prefs.getBool(_keyIsOnboarded) ?? false;
  Future<void> setOnboarded(bool value) =>
      _prefs.setBool(_keyIsOnboarded, value);

  // Flat Information
  String? get flatId => _prefs.getString(_keyFlatId);
  Future<void> setFlatId(String id) => _prefs.setString(_keyFlatId, id);

  String? get flatNumber => _prefs.getString(_keyFlatNumber);
  Future<void> setFlatNumber(String number) =>
      _prefs.setString(_keyFlatNumber, number);

  String? get blockName => _prefs.getString(_keyBlockName);
  Future<void> setBlockName(String name) => _prefs.setString(_keyBlockName, name);

  String? get societyName => _prefs.getString(_keySocietyName);
  Future<void> setSocietyName(String name) =>
      _prefs.setString(_keySocietyName, name);

  String? get cityName => _prefs.getString(_keyCityName);
  Future<void> setCityName(String name) => _prefs.setString(_keyCityName, name);

  // Save complete onboarding data
  Future<void> saveOnboardingData({
    required String flatId,
    required String flatNumber,
    required String blockName,
    required String societyName,
    required String cityName,
  }) async {
    await Future.wait([
      setFlatId(flatId),
      setFlatNumber(flatNumber),
      setBlockName(blockName),
      setSocietyName(societyName),
      setCityName(cityName),
      setOnboarded(true),
    ]);
  }

  // Clear all data (logout)
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

/// Provider for StorageService
final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StorageService(prefs);
});
