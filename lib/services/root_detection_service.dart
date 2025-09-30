import 'package:safe_device/safe_device.dart';
import 'package:flutter/foundation.dart';

class RootDetectionService {
  /// Returns true if device is compromised (rooted/jailbroken or dev mode enabled)
  /// This works COMPLETELY OFFLINE - no internet required
  Future<bool> isDeviceCompromised() async {
    try {
      // Check if device is jailbroken/rooted
      final isJailBroken = await SafeDevice.isJailBroken;

      // // Check if developer mode is enabled
      final isDevelopmentModeEnable = await SafeDevice.isDevelopmentModeEnable;
      
      // // In debug mode, only check for root/jailbreak (ignore dev mode)
      if (kDebugMode) {
        return isJailBroken;
        }
      // Device is compromised if jailbroken or dev mode on
      return isJailBroken || isDevelopmentModeEnable;
    } catch (e) {
      // If we cannot check, assume unsafe
      return true;
    }
  }
  
  // Optional: Get detailed security info
  Future<Map<String, bool>> getSecurityDetails() async {
    try {
      return {
        'isJailBroken': await SafeDevice.isJailBroken,
        'isRealDevice': await SafeDevice.isRealDevice,
        'isDeveloperMode': await SafeDevice.isDevelopmentModeEnable,
        'isOnExternalStorage': await SafeDevice.isOnExternalStorage,
      };
    } catch (e) {
      return {
        'isJailBroken': true,
        'isRealDevice': false,
        'isDeveloperMode': true,
        'isOnExternalStorage': true,
      };
    }
  }
}