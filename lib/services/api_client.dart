import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hydrogauge/config/api_config.dart';

class ApiClient {
  ApiClient({String? baseUrl, String? qrSecret})
      : _baseUrl = (() {
          // Priority: explicit arg > --dart-define > ApiConfig.baseUrl > platform defaults
          final envBase = const String.fromEnvironment('API_BASE_URL');
          if (baseUrl != null && baseUrl.trim().isNotEmpty) {
            return baseUrl;
          }
          if (envBase.trim().isNotEmpty) {
            return envBase;
          }
          if (ApiConfig.baseUrl.trim().isNotEmpty) {
            return ApiConfig.baseUrl;
          }
          if (!kIsWeb && Platform.isAndroid) {
            return 'http://10.0.2.2:8080';
          }
          return 'http://localhost:8080';
        }())
            .trim()
            .replaceAll(RegExp(r'/+$'), ''),
        _qrSecret = qrSecret ?? const String.fromEnvironment('QR_SECRET', defaultValue: 'supersecret123');

  final String _baseUrl;
  final String _qrSecret;

  Uri _u(String path, [Map<String, String>? q]) => Uri.parse('$_baseUrl$path').replace(queryParameters: q);

  Future<Map<String, dynamic>> health() async {
    final r = await http.get(_u('/health'));
    return _json(r);
  }

  Future<Map<String, dynamic>> login({required String username, required String password}) async {
    final r = await http.post(
      _u('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _json(r);
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    String? fullName,
    String? phone,
    String? role,
  }) async {
    final payload = {
      'username': username,
      'password': password,
      if (fullName != null && fullName.isNotEmpty) 'name': fullName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (role != null && role.isNotEmpty) 'role': role,
    };
    final r = await http.post(
      _u('/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return _json(r);
  }

  String _signature({required String id, required String capturedAt, String? deviceId}) {
    final data = '$id|$capturedAt|${deviceId ?? 'unknown'}';
    final mac = Hmac(sha256, utf8.encode(_qrSecret)).convert(utf8.encode(data));
    return mac.toString();
  }

  Future<Map<String, dynamic>> submitMeasurement({
    required String id,
    required String siteId,
    required String siteName,
    required double waterLevelMeters,
    required double lat,
    required double lng,
    required DateTime capturedAt,
    required String imageUrl,
    String? deviceId,
  }) async {
    final payload = {
      'id': id,
      'siteId': siteId,
      'siteName': siteName,
      'waterLevelMeters': waterLevelMeters,
      'lat': lat,
      'lng': lng,
      'capturedAt': capturedAt.toIso8601String(),
      'imageUrl': imageUrl,
      'deviceId': deviceId ?? 'unknown',
    };
    final sig = _signature(id: id, capturedAt: payload['capturedAt'] as String, deviceId: deviceId);
    final r = await http.post(
      _u('/submissions'),
      headers: {
        'Content-Type': 'application/json',
        'X-Signature': sig,
      },
      body: jsonEncode(payload),
    );
    return _json(r);
  }

  Future<Map<String, dynamic>> forecast(String siteId) async {
    final r = await http.get(_u('/sites/$siteId/forecast'));
    return _json(r);
  }

  Future<Map<String, dynamic>> anomaly(String siteId) async {
    final r = await http.get(_u('/sites/$siteId/anomaly'));
    return _json(r);
  }

  // Submissions
  Future<Map<String, dynamic>> listSubmissions({required String token, String? siteId, int? limit}) async {
    final query = <String, String>{
      if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
      if (limit != null && limit > 0) 'limit': '$limit',
    };
    final r = await http.get(
      _u('/submissions', query.isEmpty ? null : query),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _json(r);
  }

  // Sites
  Future<Map<String, dynamic>> listSites({required String token}) async {
    final r = await http.get(
      _u('/sites'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _json(r);
  }

  // Visits
  Future<Map<String, dynamic>> listVisits({required String token, String? status, String? siteId}) async {
    final query = <String, String>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
    };
    final r = await http.get(
      _u('/visits', query.isEmpty ? null : query),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _json(r);
  }

  Future<Map<String, dynamic>> scheduleVisit({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final r = await http.post(
      _u('/visits/schedule'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    return _json(r);
  }

  Map<String, dynamic> _json(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    final body = (r.body.isEmpty) ? <String, dynamic>{} : (jsonDecode(r.body) as Map<String, dynamic>);
    return body;
  }
}


