import '../../../core/auth/auth_session_manager.dart';
import '../../viewer/data/viewer_repository.dart';
import '../domain/expert_evaluator.dart';
import '../domain/mobile_ai.dart';
import 'device_resource_probe.dart';
import 'hybrid_ai_engine.dart';
import 'llama_cpp_runtime.dart';
import 'local_llama_engine.dart';
import 'local_model_manager.dart';
import 'remote_ai_engine.dart';

class MobileAiSession {
  const MobileAiSession({required this.engine, this.close});

  final MobileAiEngine engine;
  final Future<void> Function()? close;

  Future<void> dispose() async => close?.call();
}

class MobileAiSessionFactory {
  const MobileAiSessionFactory._();

  static Future<MobileAiSession> createForProject(
    MobileViewerRepository repository,
    String projectId, {
    MobileAiEngine? engine,
  }) async {
    if (engine != null) return MobileAiSession(engine: engine);
    final remote = RemoteAiEngine(
      accessTokenProvider: AuthSessionManager.getAccessToken,
      accessTokenRefresher: AuthSessionManager.refreshAccessToken,
      online: repository.isOnline,
    );
    final rulesPayload = await repository.loadOfflineRules(projectId);
    if (rulesPayload == null) return MobileAiSession(engine: remote);

    try {
      final manager = LocalModelManager(userId: repository.userId);
      final manifest = _pinnedManifest();
      final evaluator = ExpertEvaluator(ExpertRuleSet.verified(rulesPayload));
      final nativeRuntimeAvailable = await const DeviceResourceProbe()
          .hasNativeRuntime();
      final local = LocalLlamaEngine(
        evaluator: evaluator,
        available: () async =>
            nativeRuntimeAvailable && await manager.isInstalled(manifest),
        runtimeFactory: () async {
          final file = await manager.modelFile(manifest);
          return LlamaCppRuntime.create(
            modelPath: file.path,
            contextTokens: manifest.contextTokens,
          );
        },
      );
      return MobileAiSession(
        engine: HybridAiEngine(remote: remote, local: local),
        close: manager.close,
      );
    } on FormatException {
      return MobileAiSession(engine: remote);
    }
  }
}

LocalModelManifest _pinnedManifest() => LocalModelManifest(
  id: 'qwen2.5-coder-1.5b-instruct-q4-k-m',
  version: '2ab9f8f42af02fc212effaef7c4850c885e965f4',
  source: 'Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF',
  license: 'Apache-2.0',
  fileName: 'qwen2.5-coder-1.5b-instruct-q4_k_m.gguf',
  downloadUrl: Uri.parse(
    'https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/'
    '2ab9f8f42af02fc212effaef7c4850c885e965f4/'
    'qwen2.5-coder-1.5b-instruct-q4_k_m.gguf?download=true',
  ),
  byteSize: 1117320768,
  sha256Hash:
      'cc324af070c2ecbfd324a30884d2f951a7ff756aba85cb811a6ec436933bb046',
  contextTokens: 8192,
  chatTemplate:
      '<|im_start|>system\n{system}<|im_end|>\n'
      '<|im_start|>user\n{prompt}<|im_end|>\n'
      '<|im_start|>assistant\n',
  minimumRamBytes: 4294967296,
  minimumStorageBytes: 2684354560,
  architectures: const ['android-arm64', 'ios-arm64'],
  manifestChecksum: '',
);
