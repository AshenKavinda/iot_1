import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/flow_record_model.dart';
import '../models/session_model.dart';

class HistoryProvider extends ChangeNotifier {
  List<SessionModel> _sessions = [];
  List<FlowRecordModel> _flowRecords = [];
  bool _sessionsError = false;
  bool _flowError = false;

  StreamSubscription<DatabaseEvent>? _sessionsSubscription;
  StreamSubscription<DatabaseEvent>? _flowSubscription;

  List<SessionModel> get sessions => _sessions;
  List<FlowRecordModel> get flowRecords => _flowRecords;
  bool get hasError => _sessionsError || _flowError;

  HistoryProvider() {
    _listenSessions();
    _listenFlow();
  }

  void _listenSessions() {
    _sessionsSubscription = FirebaseDatabase.instance
        .ref('/history/sessions')
        .onValue
        .listen(
      (event) {
        _sessionsError = false;
        if (event.snapshot.exists && event.snapshot.value != null) {
          final map = event.snapshot.value as Map<dynamic, dynamic>;
          _sessions = map.entries
              .where((e) => e.value is Map)
              .map((e) => SessionModel.fromMap(
                  e.key.toString(), e.value as Map<dynamic, dynamic>))
              .toList()
            ..sort((a, b) => b.epochMs.compareTo(a.epochMs));
        } else {
          _sessions = [];
        }
        notifyListeners();
      },
      onError: (_) {
        _sessionsError = true;
        notifyListeners();
      },
    );
  }

  void _listenFlow() {
    _flowSubscription = FirebaseDatabase.instance
        .ref('/history/flow')
        .onValue
        .listen(
      (event) {
        _flowError = false;
        if (event.snapshot.exists && event.snapshot.value != null) {
          final map = event.snapshot.value as Map<dynamic, dynamic>;
          _flowRecords = map.entries
              .where((e) => e.value is Map)
              .map((e) => FlowRecordModel.fromMap(
                  e.key.toString(), e.value as Map<dynamic, dynamic>))
              .toList()
            ..sort((a, b) => b.epochMs.compareTo(a.epochMs));
        } else {
          _flowRecords = [];
        }
        notifyListeners();
      },
      onError: (_) {
        _flowError = true;
        notifyListeners();
      },
    );
  }

  Future<void> clearHistory() async {
    await Future.wait([
      FirebaseDatabase.instance.ref('/history/flow').remove(),
      FirebaseDatabase.instance.ref('/history/sessions').remove(),
    ]);
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    _flowSubscription?.cancel();
    super.dispose();
  }
}
