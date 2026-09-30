/// Contract for anything that provides data to the app.
/// Both MockDataSource and ServerDataSource implement this,
/// so the provider can switch between them freely.
abstract class DataSource {
  Future<Map<String, dynamic>> fetchFleet();
  Future<Map<String, dynamic>> fetchLatest(String buoyId);
  Future<Map<String, dynamic>> fetchHistory(String buoyId);
  Future<Map<String, dynamic>> fetchComparison();
  Future<Map<String, dynamic>> fetchInterpretation(String buoyId);
}
