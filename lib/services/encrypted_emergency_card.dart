import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// Portable encrypted file: keys and passwords never leave this device.
class EncryptedEmergencyCard {
  static final _cipher = AesGcm.with256bits();
  static Future<SecretKey> _key(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  static Future<List<int>> encrypt(
    Map<String, dynamic> card,
    String password,
  ) async {
    if (password.length < 12) {
      throw ArgumentError('Use at least 12 characters.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(card)),
      secretKey: await _key(password, salt),
    );
    return utf8.encode(
      jsonEncode({
        'v': 1,
        'salt': base64Encode(salt),
        'nonce': base64Encode(box.nonce),
        'cipher': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      }),
    );
  }

  static Future<Map<String, dynamic>> decrypt(
    List<int> bytes,
    String password,
  ) async {
    if (bytes.length > 100000) throw const FormatException('Card too large.');
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (envelope['v'] != 1) {
      throw const FormatException('Unsupported card version.');
    }
    final salt = base64Decode(envelope['salt']);
    final nonce = base64Decode(envelope['nonce']);
    final mac = base64Decode(envelope['mac']);
    if (salt.length != 16 || nonce.length != 12 || mac.length != 16) {
      throw const FormatException('Invalid card.');
    }
    final plain = await _cipher.decrypt(
      SecretBox(base64Decode(envelope['cipher']), nonce: nonce, mac: Mac(mac)),
      secretKey: await _key(password, salt),
    );
    final card = Map<String, dynamic>.from(jsonDecode(utf8.decode(plain)));
    if (card['savedAt'] is! String || card['userName'] is! String) {
      throw const FormatException('Invalid emergency card.');
    }
    return card;
  }
}
