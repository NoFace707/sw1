import '../../../core/network/api_client.dart';
import 'local_model_manager.dart';

class LocalModelManifestRepository {
  LocalModelManifestRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<LocalModelManifest> load(String accessToken) async {
    final response = await _apiClient.get(
      '/api/modeling/ai/local-model/manifest/',
      accessToken: accessToken,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('No se pudo obtener el manifiesto del modelo local.');
    }
    return LocalModelManifest.verified(_apiClient.parseJsonMap(response));
  }
}
