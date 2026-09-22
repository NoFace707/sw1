import '../domain/mobile_ai.dart';

class HybridAiEngine implements MobileAiEngine {
  HybridAiEngine({required this.remote, required this.local});

  final MobileAiEngine remote;
  final MobileAiEngine local;

  @override
  String get id => 'hybrid';

  @override
  Future<bool> isAvailable() async =>
      await remote.isAvailable() || await local.isAvailable();

  @override
  Future<MobileAiResponse> propose(
    MobileAiRequest request, {
    MobileAiCancellation? cancellation,
    void Function(String token)? onToken,
  }) async {
    switch (request.mode) {
      case MobileAiMode.api:
        return remote.propose(
          request,
          cancellation: cancellation,
          onToken: onToken,
        );
      case MobileAiMode.local:
        return local.propose(
          request,
          cancellation: cancellation,
          onToken: onToken,
        );
      case MobileAiMode.automatic:
        if (await remote.isAvailable()) {
          try {
            return await remote.propose(
              request,
              cancellation: cancellation,
              onToken: onToken,
            );
          } on MobileAiException catch (error) {
            if (error.code == 'cancelled' || !await local.isAvailable()) {
              rethrow;
            }
          }
        }
        return local.propose(
          request,
          cancellation: cancellation,
          onToken: onToken,
        );
    }
  }
}
