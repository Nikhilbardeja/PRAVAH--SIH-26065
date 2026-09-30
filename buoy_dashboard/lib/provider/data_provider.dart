import 'dart:async';
import 'package:flutter/foundation.dart';
import '../src/data_source.dart';
import '../src/mock_data_source.dart';
import '../src/server_data_source.dart';

/// Holds app data. Gets it from MockDataSource or ServerDataSource
/// depending on [useMock]. Screens only read from here.
///
/// In server mode the data refreshes itself every [pollInterval] (silently:
/// no spinner, and a failed poll keeps showing the last good data).
class DataProvider extends ChangeNotifier {
  static const Duration pollInterval = Duration(seconds: 5);

  final DataSource _mockSource = MockDataSource();
  final DataSource _serverSource = ServerDataSource();

  bool useMock = false; // false = talk to the buoy server
  bool loading = false;
  bool lastPollFailed = false; // true while the server is unreachable
  String? error;
  String selectedBuoy = 'SO-01';
  DateTime? updatedAt;
  int _requestId = 0; // ignores stale responses after quick toggles
  bool _silentBusy = false;
  Timer? _timer;

  Map<String, dynamic> fleet = {};
  Map<String, dynamic> latest = {};
  Map<String, dynamic> history = {};
  Map<String, dynamic> comparison = {};
  Map<String, dynamic> interpretation = {};

  DataProvider() {
    _timer = Timer.periodic(pollInterval, (_) {
      if (!useMock && !loading && !_silentBusy) load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DataSource get _source => useMock ? _mockSource : _serverSource;
  String get sourceName => useMock ? 'MOCK' : 'SERVER';

  Future<void> load({bool silent = false}) async {
    final id = ++_requestId;
    if (silent) {
      _silentBusy = true;
    } else {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final s = _source;
      final r = await Future.wait([
        s.fetchFleet(),
        s.fetchLatest(selectedBuoy),
        s.fetchHistory(selectedBuoy),
        s.fetchComparison(),
        s.fetchInterpretation(selectedBuoy),
      ]);
      if (id != _requestId) return;
      fleet = r[0];
      latest = r[1];
      history = r[2];
      comparison = r[3];
      interpretation = r[4];
      updatedAt = DateTime.now();
      error = null;
      lastPollFailed = false;
    } catch (e) {
      if (id != _requestId) return;
      if (silent && updatedAt != null) {
        lastPollFailed = true; // keep the last good data on screen
        notifyListeners();
        return;
      }
      error = e.toString();
    } finally {
      if (silent) _silentBusy = false;
    }

    loading = false;
    notifyListeners();
  }

  void toggleSource() {
    useMock = !useMock;
    load();
  }

  void selectBuoy(String id) {
    selectedBuoy = id;
    load();
  }

  List<String> get buoyIds {
    final ids = <String>[
      for (final b in (fleet['buoys'] as List? ?? []))
        if (b is Map && b['id'] != null) b['id'].toString()
    ];
    if (!ids.contains(selectedBuoy)) ids.insert(0, selectedBuoy);
    return ids;
  }
}
