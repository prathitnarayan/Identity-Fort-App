// Updated otp_storage_service.dart
import 'dart:convert';
import 'package:identity_fort/services/storage_service.dart'; // Import the shared storage service

class OTPStorageService {
  static final StorageService _storageService = StorageService();
  static const String _accountsKey = 'otp_accounts';

  static Future<List<Map<String, dynamic>>> loadAccounts() async {
    try {
      final jsonString = await _storageService.read(_accountsKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error loading accounts: $e');
      return [];
    }
  }

  static Future<void> saveAccounts(List<Map<String, dynamic>> accounts) async {
    try {
      final jsonString = jsonEncode(accounts);
      await _storageService.write(_accountsKey, jsonString);
    } catch (e) {
      print('Error saving accounts: $e');
    }
  }

  static Future<bool> addAccount(Map<String, dynamic> account) async {
    try {
      final accounts = await loadAccounts();
      
      // Check if account already exists (by issuer and accountName)
      final exists = accounts.any((acc) =>
          acc['issuer'] == account['issuer'] &&
          acc['accountName'] == account['accountName']);
      
      if (exists) {
        return false; // Account already exists
      }
      
      accounts.add(account);
      await saveAccounts(accounts);
      return true;
    } catch (e) {
      print('Error adding account: $e');
      return false;
    }
  }

  static Future<void> removeAccount(int index) async {
    try {
      final accounts = await loadAccounts();
      if (index >= 0 && index < accounts.length) {
        accounts.removeAt(index);
        await saveAccounts(accounts);
      }
    } catch (e) {
      print('Error removing account: $e');
    }
  }

  static Future<void> clearAllAccounts() async {
    try {
      await _storageService.delete(_accountsKey);
    } catch (e) {
      print('Error clearing accounts: $e');
    }
  }

  // Debug method to check storage contents
  static Future<void> debugStorage() async {
    try {
      final allData = await _storageService.readAll();
      print('All storage data: $allData');
    } catch (e) {
      print('Error reading all storage: $e');
    }
  }
}