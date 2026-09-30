import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/server_url.dart';
import 'data_source.dart';

/// Fetches data from the server defined in core/server_url.dart.
/// This is the ONLY place in the app that makes network requests.
class ServerDataSource implements DataSource {
  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('${ServerUrl.baseUrl}$path');
    final res = await http
        .get(uri, headers: ServerUrl.headers)
        .timeout(ServerUrl.timeout);

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} on $path');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    return {'items': decoded}; // server returned a bare list
  }

  @override
  Future<Map<String, dynamic>> fetchFleet() => _get(Endpoints.fleet);

  @override
  Future<Map<String, dynamic>> fetchLatest(String buoyId) => _get(Endpoints.latest(buoyId));

  @override
  Future<Map<String, dynamic>> fetchHistory(String buoyId) => _get(Endpoints.history(buoyId));

  @override
  Future<Map<String, dynamic>> fetchComparison() => _get(Endpoints.comparison);

  @override
  Future<Map<String, dynamic>> fetchInterpretation(String buoyId) =>
      _get(Endpoints.interpretation(buoyId));
}
