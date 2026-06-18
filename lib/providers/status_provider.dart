import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/status_model.dart';

class StatusProvider extends ChangeNotifier {
  StatusModel _status = StatusModel.defaultValue;
  bool _hasError = false;
  bool _isLoading = true;
  DateTime? _lastUpdated;
  StreamSubscription<DatabaseEvent>? _subscription;

  StatusModel get status => _status;
  bool get hasError => _hasError;
  bool get isLoading => _isLoading;
  DateTime? get lastUpdated => _lastUpdated;

  StatusProvider() {
    _listen();
  }

  void _listen() {
    _subscription =
        FirebaseDatabase.instance.ref('/status').onValue.listen(
      (event) {
        _isLoading = false;
        _hasError = false;
        if (event.snapshot.exists && event.snapshot.value != null) {
          final map = event.snapshot.value as Map<dynamic, dynamic>;
          _status = StatusModel.fromMap(map);
          _lastUpdated = DateTime.now();
        }
        notifyListeners();
      },
      onError: (_) {
        _isLoading = false;
        _hasError = true;
        notifyListeners();
      },
    );
  }

  Future<void> setManualOverride(bool value) async {
    await FirebaseDatabase.instance.ref('/pump/manualOverride').set(value);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
