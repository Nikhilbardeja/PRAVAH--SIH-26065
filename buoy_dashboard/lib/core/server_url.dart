import 'package:flutter/foundation.dart';

/// Where the app finds the buoy server (no trailing slash).
///
/// Picked automatically:
///   Flutter Web / desktop / iOS simulator -> http://127.0.0.1:5000
///   Android emulator                      -> http://10.0.2.2:5000  (host machine)
/// Physical phone or custom host - override at build time:
///   flutter run --dart-define=API_BASE=http://192.168.1.20:5000
class ServerUrl {
  static const String _override = String.fromEnvironment('API_BASE');

  static String get baseUrl {
    if (_override.isNotEmpty) {
      return _override.endsWith('/')
          ? _override.substring(0, _override.length - 1)
          : _override;
    }
    if (kIsWeb) return 'http://127.0.0.1:5000';
    if (defaultTargetPlatform == TargetPlatform.android)
      return 'http://10.0.2.2:5000';
    return 'http://127.0.0.1:5000';
  }

  /// Headers sent with every request (add auth token here if needed).
  static const Map<String, String> headers = {
    'Accept': 'application/json',
    // 'Authorization': 'Bearer YOUR_TOKEN',
  };

  static const Duration timeout = Duration(seconds: 10);
}

/// All endpoint paths used by the app.
class Endpoints {
  static const String fleet = '/api/fleet';
  static String latest(String buoyId) => '/api/buoys/$buoyId/latest';
  static String history(String buoyId) => '/api/buoys/$buoyId/history?days=14';
  static const String comparison = '/api/comparison';
  static String interpretation(String buoyId) =>
      '/api/interpretation?buoy=$buoyId';
}
