import 'dart:convert';

import 'package:http/http.dart' as http;

class LicenseApiClient {
  LicenseApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? 'https://license.airmonlink.com/api/v1';

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> activate({
    required String licenseKey,
    required String deviceIdentifier,
    required String appVersion,
    required String platform,
    required String? businessName,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/activate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'licenseKey': licenseKey,
        'deviceIdentifier': deviceIdentifier,
        'appVersion': appVersion,
        'platform': platform,
        'businessName': businessName,
      }),
    );

    if (response.statusCode >= 400) {
      throw StateError('The licence server rejected the activation request.');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> validate({
    required String token,
    required String deviceIdentifier,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/validate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'deviceIdentifier': deviceIdentifier}),
    );

    if (response.statusCode >= 400) {
      throw StateError('The licence server could not validate the licence.');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deactivate({required String token}) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/deactivate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode >= 400) {
      throw StateError('The licence server could not deactivate the licence.');
    }
  }

  Future<List<dynamic>> plans() async {
    final response = await _client.get(Uri.parse('$_baseUrl/plans'));
    if (response.statusCode >= 400) {
      return const [];
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> status() async {
    final response = await _client.get(Uri.parse('$_baseUrl/status'));
    if (response.statusCode >= 400) {
      return {'status': 'offline'};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
