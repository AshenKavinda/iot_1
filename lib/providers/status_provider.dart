import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/status_model.dart';

class StatusProvider extends ChangeNotifier {
  StatusModel _status = StatusModel.defaultValue;
  bool _hasError = false;
  bool _isLoading = true;
  DateTime? _lastUpdated;
  Timer? _pollTimer;

  StatusModel get status => _status;
  bool get hasError => _hasError;
  bool get isLoading => _isLoading;
  DateTime? get lastUpdated => _lastUpdated;

  static const String _databaseUrl =
      'https://iot-2026-tharuka-default-rtdb.firebaseio.com';

  StatusProvider() {
    _startPolling();
  }

  Future<Map<dynamic, dynamic>?> _fetchJson(String path) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse('$_databaseUrl$path.json'));
      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('[STATUS] HTTP ${response.statusCode} for $path');
        client.close();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      client.close();
      if (body.isEmpty || body == 'null') return null;
      return jsonDecode(body) as Map<dynamic, dynamic>;
    } catch (e) {
      debugPrint('[STATUS] HTTP fetch error for $path: $e');
      return null;
    }
  }

  void _startPolling() {
    _pollOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    final data = await _fetchJson('/status');
    if (data != null) {
      _isLoading = false;
      _hasError = false;
      try {
        _status = StatusModel.fromMap(data);
        _lastUpdated = DateTime.now();
      } catch (e) {
        debugPrint('[STATUS] Parse error: $e');
      }
    } else {
      if (!_isLoading) _hasError = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setManualOverride(bool value) async {
    try {
      final client = HttpClient();
      final request = await client.putUrl(
        Uri.parse('$_databaseUrl/pump/manualOverride.json'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(value));
      await request.close().then((r) => r.drain());
      client.close();
    } catch (e) {
      debugPrint('[STATUS] setManualOverride error: $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
