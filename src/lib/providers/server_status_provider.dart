import 'package:flutter/foundation.dart';

import '../data/api/api_exception.dart';
import '../data/models/analytics.dart';
import '../data/repositories/analytics_repository.dart';

/// Tracks what the server actually reports about itself.
///
/// The demo banner is driven from `/readyz.demo_mode`, never hardcoded: if the
/// app is pointed at a production instance the banner disappears on its own,
/// and if it is pointed at a seeded demo instance the banner is honest.
class ServerStatusProvider extends ChangeNotifier {
  ServerStatusProvider(this._repo);
  final AnalyticsRepository _repo;

  ServerStatus? _status;
  bool _reachable = false;
  String? _error;

  ServerStatus? get status => _status;
  bool get reachable => _reachable;
  String? get error => _error;

  /// Defaults to false: a banner claiming "demo data" over real records would
  /// be worse than no banner at all.
  bool get demoMode => _status?.demoMode ?? false;

  Future<void> refresh() async {
    try {
      _status = await _repo.status();
      _reachable = true;
      _error = null;
    } on ApiException catch (e) {
      _reachable = false;
      _error = e.message;
    }
    notifyListeners();
  }
}
