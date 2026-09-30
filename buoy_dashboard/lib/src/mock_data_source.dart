import 'data_source.dart';
import 'mock_data.dart';

/// Returns hardcoded data from mock_data.dart (no network).
class MockDataSource implements DataSource {
  static const _delay = Duration(milliseconds: 250); // simulate network

  Future<Map<String, dynamic>> _mock(Map<String, dynamic> data) =>
      Future.delayed(_delay, () => data);

  @override
  Future<Map<String, dynamic>> fetchFleet() => _mock(MockData.fleet);

  @override
  Future<Map<String, dynamic>> fetchLatest(String buoyId) => _mock(MockData.latest);

  @override
  Future<Map<String, dynamic>> fetchHistory(String buoyId) => _mock(MockData.history(buoyId));

  @override
  Future<Map<String, dynamic>> fetchComparison() => _mock(MockData.comparison);

  @override
  Future<Map<String, dynamic>> fetchInterpretation(String buoyId) =>
      _mock(MockData.interpretation);
}
