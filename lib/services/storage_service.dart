// Create a shared storage service: storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  // Singleton pattern to ensure consistent storage configuration
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Use consistent storage configuration across the app
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    // iOptions: IOSOptions(
    //   accessibility: KeychainAccessibility.first_unlock_this_device_only,
    // ),
  );

  // Method to get the secure storage instance
  FlutterSecureStorage get secureStorage => _secureStorage;

  // Convenience methods for common operations
  Future<String?> read(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      print('Error reading from secure storage: $e');
      return null;
    }
  }

  Future<void> write(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      print('Error writing to secure storage: $e');
    }
  }

  Future<void> delete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      print('Error deleting from secure storage: $e');
    }
  }

  Future<void> deleteAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      print('Error deleting all from secure storage: $e');
    }
  }

  Future<Map<String, String>> readAll() async {
    try {
      return await _secureStorage.readAll();
    } catch (e) {
      print('Error reading all from secure storage: $e');
      return {};
    }
  }
}
