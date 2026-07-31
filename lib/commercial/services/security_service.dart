import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class SecurityService {
  const SecurityService();

  static const _defaultIterations = 120000;

  String hashPin(String pin, {int iterations = _defaultIterations}) {
    if (pin.length < 4) {
      throw ArgumentError('PIN must contain at least four characters.');
    }
    final salt = _randomBytes(16);
    final derived = _pbkdf2(
      utf8.encode(pin),
      salt,
      iterations: iterations,
      length: 32,
    );
    return 'pbkdf2_sha256\$$iterations\$${base64UrlEncode(salt)}\$${base64UrlEncode(derived)}';
  }

  bool verifyPin(String pin, String encoded) {
    final parts = encoded.split(r'$');
    if (parts.length == 4 && parts.first == 'pbkdf2_sha256') {
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 10000) return false;
      try {
        final salt = base64Url.decode(parts[2]);
        final expected = base64Url.decode(parts[3]);
        final actual = _pbkdf2(
          utf8.encode(pin),
          salt,
          iterations: iterations,
          length: expected.length,
        );
        return _constantTimeEquals(actual, expected);
      } catch (_) {
        return false;
      }
    }

    // Build 7 migration support for an old, unsalted SHA-256 value.
    if (RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(encoded)) {
      final actual = sha256.convert(utf8.encode(pin)).toString();
      return _constantTimeEquals(
        utf8.encode(actual.toLowerCase()),
        utf8.encode(encoded.toLowerCase()),
      );
    }
    return false;
  }

  bool needsUpgrade(String encoded) => !encoded.startsWith('pbkdf2_sha256\$');

  String randomToken({int bytes = 32}) => base64UrlEncode(_randomBytes(bytes));

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt, {
    required int iterations,
    required int length,
  }) {
    final hmac = Hmac(sha256, password);
    final hashLength = 32;
    final blocks = (length / hashLength).ceil();
    final result = BytesBuilder(copy: false);
    for (var block = 1; block <= blocks; block++) {
      final blockBytes = ByteData(4)..setUint32(0, block, Endian.big);
      var u = hmac.convert([...salt, ...blockBytes.buffer.asUint8List()]).bytes;
      final output = Uint8List.fromList(u);
      for (var round = 1; round < iterations; round++) {
        u = hmac.convert(u).bytes;
        for (var i = 0; i < output.length; i++) {
          output[i] ^= u[i];
        }
      }
      result.add(output);
    }
    return Uint8List.fromList(result.takeBytes().take(length).toList());
  }

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left[i] ^ right[i];
    }
    return difference == 0;
  }
}
