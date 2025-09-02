// lib/services/backend_qr_decoder_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

class BackendQRDecoderService {
  // These keys must match your backend configuration
  // Update these to match your actual backend keys
  static const String AES_KEY_32 =
      '12345678901234567890123456789012'; // For AES-256
  static const String AES_KEY_16 =
      '12345678901234567890123456789012'; // For AES-128
  static const String HMAC_KEY = 'my_secure_hmac_key';

  /// Decodes QR payload from your Spring Boot backend
  /// The QR should contain base64-encoded encrypted data
  static Future<Map<String, String>?> decodeQRPayload(String qrPayload) async {
    try {
      print('Attempting to decode QR payload length: ${qrPayload.length}');
      print(
        'QR payload preview: ${qrPayload.length > 50 ? qrPayload.substring(0, 50) + "..." : qrPayload}',
      );

      // Step 1: Try different decoding approaches based on QR format

      // Approach 1: Direct base64 decoding of encrypted data
      Map<String, String>? result = await _decodeEncryptedPayload(qrPayload);
      if (result != null) return result;

      // Approach 2: Check if it's a JSON payload with encrypted content
      result = await _decodeJSONPayload(qrPayload);
      if (result != null) return result;

      // Approach 3: Handle URL-encoded or other formats
      result = await _decodeURLEncodedPayload(qrPayload);
      if (result != null) return result;

      // Approach 4: Plain text format (username:secret)
      result = _decodePlainTextPayload(qrPayload);
      if (result != null) return result;

      print('Unable to decode QR payload with any known format');
      return null;
    } catch (e) {
      print('Error in decodeQRPayload: $e');
      return null;
    }
  }

  /// Decode direct encrypted payload
  static Future<Map<String, String>?> _decodeEncryptedPayload(
    String payload,
  ) async {
    try {
      // Try base64 decoding first
      final encryptedBytes = base64Decode(payload);
      print('Successfully decoded base64, length: ${encryptedBytes.length}');

      // Try AES-256 first, then AES-128
      String? decrypted = await _decryptAES256(encryptedBytes);
      decrypted ??= await _decryptAES128(encryptedBytes);

      if (decrypted != null) {
        return _parseDecryptedData(decrypted);
      }
    } catch (e) {
      print('Failed to decode as encrypted payload: $e');
    }
    return null;
  }

  /// Decode JSON payload that might contain encrypted data
  static Future<Map<String, String>?> _decodeJSONPayload(String payload) async {
    try {
      final jsonData = jsonDecode(payload);
      if (jsonData is Map<String, dynamic>) {
        // Case 1: Direct secret in JSON
        if (jsonData.containsKey('secret') &&
            jsonData.containsKey('username')) {
          return {
            'secret': jsonData['secret']
                .toString()
                .replaceAll(' ', '')
                .toUpperCase(),
            'issuer': jsonData['issuer']?.toString() ?? 'IdentityFort',
            'accountName': jsonData['username'].toString(),
          };
        }

        // Case 2: Encrypted data in JSON
        if (jsonData.containsKey('encryptedData')) {
          final encryptedBytes = base64Decode(
            jsonData['encryptedData'].toString(),
          );

          String? decrypted = await _decryptAES256(encryptedBytes);
          decrypted ??= await _decryptAES128(encryptedBytes);

          if (decrypted != null) {
            return _parseDecryptedData(decrypted);
          }
        }

        // Case 3: QR data field
        if (jsonData.containsKey('qrData')) {
          return await _decodeEncryptedPayload(jsonData['qrData'].toString());
        }
      }
    } catch (e) {
      print('Failed to decode as JSON payload: $e');
    }
    return null;
  }

  /// Decode URL-encoded payload
  static Future<Map<String, String>?> _decodeURLEncodedPayload(
    String payload,
  ) async {
    try {
      final decoded = Uri.decodeComponent(payload);
      if (decoded != payload) {
        // It was URL encoded, try decoding the result
        return await decodeQRPayload(decoded);
      }
    } catch (e) {
      print('Failed to decode as URL-encoded payload: $e');
    }
    return null;
  }

  /// Decode plain text payload (username:secret format)
  static Map<String, String>? _decodePlainTextPayload(String payload) {
    try {
      if (payload.contains(':')) {
        final parts = payload.split(':');
        if (parts.length >= 2) {
          final username = parts[0].trim();
          final secret = parts[1].trim().replaceAll(' ', '').toUpperCase();

          // Validate secret format (should be base32)
          if (_isValidBase32Secret(secret)) {
            return {
              'secret': secret,
              'issuer': 'IdentityFort',
              'accountName': username,
            };
          }
        }
      }
    } catch (e) {
      print('Failed to decode as plain text payload: $e');
    }
    return null;
  }

  /// Decrypt AES-256 encrypted data (32-byte key)
  static Future<String?> _decryptAES256(Uint8List encryptedBytes) async {
    try {
      // Ensure key is exactly 32 characters for AES-256
      final keyString = AES_KEY_32.padRight(32, '0').substring(0, 32);
      final key = Key.fromUtf8(keyString);

      // Try different AES modes
      final modes = [AESMode.cbc, AESMode.ecb];

      for (final mode in modes) {
        try {
          final encrypter = Encrypter(AES(key, mode: mode, padding: 'PKCS7'));

          if (mode == AESMode.cbc) {
            // For CBC, we need IV (usually first 16 bytes)
            if (encryptedBytes.length > 16) {
              final iv = IV(encryptedBytes.sublist(0, 16));
              final encryptedData = Encrypted(encryptedBytes.sublist(16));
              final decrypted = encrypter.decrypt(encryptedData, iv: iv);
              print('Successfully decrypted with AES-256 $mode mode');
              return decrypted;
            }
          } else {
            // For ECB mode, no IV needed
            final encryptedData = Encrypted(encryptedBytes);
            final decrypted = encrypter.decrypt(encryptedData);
            print('Successfully decrypted with AES-256 $mode mode');
            return decrypted;
          }
        } catch (e) {
          print('Failed to decrypt with AES-256 $mode: $e');
          continue;
        }
      }
    } catch (e) {
      print('Error in AES-256 decryption: $e');
    }
    return null;
  }

  /// Decrypt AES-128 encrypted data (16-byte key)
  static Future<String?> _decryptAES128(Uint8List encryptedBytes) async {
    try {
      // Ensure key is exactly 16 characters for AES-128
      final keyString = AES_KEY_16.padRight(16, '0').substring(0, 16);
      final key = Key.fromUtf8(keyString);

      // Try different AES modes
      final modes = [AESMode.cbc, AESMode.ecb];

      for (final mode in modes) {
        try {
          final encrypter = Encrypter(AES(key, mode: mode, padding: 'PKCS7'));

          if (mode == AESMode.cbc) {
            // For CBC, we need IV (usually first 16 bytes)
            if (encryptedBytes.length > 16) {
              final iv = IV(encryptedBytes.sublist(0, 16));
              final encryptedData = Encrypted(encryptedBytes.sublist(16));
              final decrypted = encrypter.decrypt(encryptedData, iv: iv);
              print('Successfully decrypted with AES-128 $mode mode');
              return decrypted;
            }
          } else {
            // For ECB mode, no IV needed
            final encryptedData = Encrypted(encryptedBytes);
            final decrypted = encrypter.decrypt(encryptedData);
            print('Successfully decrypted with AES-128 $mode mode');
            return decrypted;
          }
        } catch (e) {
          print('Failed to decrypt with AES-128 $mode: $e');
          continue;
        }
      }
    } catch (e) {
      print('Error in AES-128 decryption: $e');
    }
    return null;
  }

  /// Parse decrypted data into account information
  static Map<String, String>? _parseDecryptedData(String decryptedData) {
    try {
      print('Parsing decrypted data: $decryptedData');

      // Try JSON first
      try {
        final jsonData = jsonDecode(decryptedData);
        if (jsonData is Map<String, dynamic> &&
            jsonData.containsKey('secret') &&
            jsonData.containsKey('username')) {
          return {
            'secret': jsonData['secret']
                .toString()
                .replaceAll(' ', '')
                .toUpperCase(),
            'issuer': jsonData['issuer']?.toString() ?? 'IdentityFort',
            'accountName': jsonData['username'].toString(),
          };
        }
      } catch (e) {
        // Not JSON, continue with other formats
      }

      // Try delimiter-based formats
      final delimiters = [':', '|', ',', ';'];
      for (final delimiter in delimiters) {
        if (decryptedData.contains(delimiter)) {
          final parts = decryptedData.split(delimiter);
          if (parts.length >= 2) {
            final username = parts[0].trim();
            final secret = parts[1].trim().replaceAll(' ', '').toUpperCase();

            // Validate secret format (should be base32)
            if (_isValidBase32Secret(secret)) {
              return {
                'secret': secret,
                'issuer': 'IdentityFort',
                'accountName': username,
              };
            }
          }
        }
      }

      print('Unable to parse decrypted data format');
      return null;
    } catch (e) {
      print('Error parsing decrypted data: $e');
      return null;
    }
  }

  /// Validate if the secret is a valid base32 string
  static bool _isValidBase32Secret(String secret) {
    // Base32 should only contain A-Z and 2-7, and be properly padded
    final base32Pattern = RegExp(r'^[A-Z2-7]+=*$');
    return secret.length >= 16 && // Minimum reasonable length
        secret.length <= 64 && // Maximum reasonable length
        base32Pattern.hasMatch(secret);
  }
}
