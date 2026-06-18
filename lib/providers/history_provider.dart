import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/flow_record_model.dart';
import '../models/session_model.dart';

class HistoryProvider extends ChangeNotifier {
  List<SessionModel> _sessions = [];
  List<FlowRecordModel> _flowRecords = [];
  bool _hasError = false;
  Timer? _pollTimer;

  List<SessionModel> get sessions => _sessions;
  List<FlowRecordModel> get flowRecords => _flowRecords;
  bool get hasError => _hasError;

  static const String _databaseUrl =
      'https://iot-2026-tharuka-default-rtdb.firebaseio.com';

  HistoryProvider() {
    _pollOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollOnce());
  }

  Future<Map<dynamic, dynamic>?> _fetchJson(String path) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse('$_databaseUrl$path.json'));
      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('[HISTORY] HTTP ${response.statusCode} for $path');
        client.close();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      client.close();
      if (body.isEmpty || body == 'null') return null;
      return jsonDecode(body) as Map<dynamic, dynamic>;
    } catch (e) {
      debugPrint('[HISTORY] HTTP fetch error for $path: $e');
      return null;
    }
  }

  Future<void> _pollOnce() async {
    try {
      final results = await Future.wait([
        _fetchJson('/history/sessions'),
        _fetchJson('/history/flow'),
      ]);

      _hasError = false;

      final sessionsData = results[0];
      if (sessionsData != null) {
        _sessions = sessionsData.entries
            .where((e) => e.value is Map)
            .map((e) => SessionModel.fromMap(
                e.key.toString(), e.value as Map<dynamic, dynamic>))
            .toList()
          ..sort((a, b) => b.epochMs.compareTo(a.epochMs));
      } else {
        _sessions = [];
      }

      final flowData = results[1];
      if (flowData != null) {
        _flowRecords = flowData.entries
            .where((e) => e.value is Map)
            .map((e) => FlowRecordModel.fromMap(
                e.key.toString(), e.value as Map<dynamic, dynamic>))
            .toList()
          ..sort((a, b) => b.epochMs.compareTo(a.epochMs));
      } else {
        _flowRecords = [];
      }
    } catch (e) {
      _hasError = true;
      debugPrint('[HISTORY] Poll error: $e');
    }
    notifyListeners();
  }

  Future<void> clearHistory() async {
    try {
      final client = HttpClient();
      for (final path in ['/history/flow.json', '/history/sessions.json']) {
        final request = await client.deleteUrl(Uri.parse('$_databaseUrl$path'));
        await request.close().then((r) => r.drain());
      }
      client.close();
      _sessions = [];
      _flowRecords = [];
      notifyListeners();
    } catch (e) {
      debugPrint('[HISTORY] clearHistory error: $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
